/*
 File: AVCamViewController.m
 Abstract: View controller for camera interface.
 Version: 3.1
 
 Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
 Inc. ("Apple") in consideration of your agreement to the following
 terms, and your use, installation, modification or redistribution of
 this Apple software constitutes acceptance of these terms.  If you do
 not agree with these terms, please do not use, install, modify or
 redistribute this Apple software.
 
 In consideration of your agreement to abide by the following terms, and
 subject to these terms, Apple grants you a personal, non-exclusive
 license, under Apple's copyrights in this original Apple software (the
 "Apple Software"), to use, reproduce, modify and redistribute the Apple
 Software, with or without modifications, in source and/or binary forms;
 provided that if you redistribute the Apple Software in its entirety and
 without modifications, you must retain this notice and the following
 text and disclaimers in all such redistributions of the Apple Software.
 Neither the name, trademarks, service marks or logos of Apple Inc. may
 be used to endorse or promote products derived from the Apple Software
 without specific prior written permission from Apple.  Except as
 expressly stated in this notice, no other rights or licenses, express or
 implied, are granted by Apple herein, including but not limited to any
 patent rights that may be infringed by your derivative works or by other
 works in which the Apple Software may be incorporated.
 
 The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
 MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
 THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
 FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
 OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.
 
 IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
 OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
 MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
 AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
 STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE.
 
 Copyright (C) 2014 Apple Inc. All Rights Reserved.
 
 */

#import "AVCamViewController.h"

#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <MediaPlayer/MediaPlayer.h>

#import "AVCamPreviewView.h"

static void * CapturingStillImageContext = &CapturingStillImageContext;
static void * RecordingContext = &RecordingContext;
static void * SessionRunningAndDeviceAuthorizedContext = &SessionRunningAndDeviceAuthorizedContext;

@interface AVCamViewController () <AVCaptureFileOutputRecordingDelegate>

// For use in the storyboards.
@property (nonatomic, weak) IBOutlet AVCamPreviewView *previewView;
@property (nonatomic, weak) IBOutlet UIButton *recordButton;
@property (nonatomic, weak) IBOutlet UIButton *cameraButton;
@property (nonatomic, weak) IBOutlet UIButton *stillButton;

- (IBAction)snapStillImage:(id)sender;

// Session management.
@property (nonatomic) dispatch_queue_t sessionQueue; // Communicate with the session and other session objects on this queue.
@property (nonatomic) AVCaptureSession *session;
//@property (nonatomic) AVCaptureDeviceInput *videoDeviceInput;
//@property (nonatomic) AVCaptureMovieFileOutput *movieFileOutput;
@property (nonatomic) AVCaptureStillImageOutput *stillImageOutput;

// Utilities.
@property (nonatomic) UIBackgroundTaskIdentifier backgroundRecordingID;
@property (nonatomic, getter = isDeviceAuthorized) BOOL deviceAuthorized;
@property (nonatomic, readonly, getter = isSessionRunningAndDeviceAuthorized) BOOL sessionRunningAndDeviceAuthorized;
@property (nonatomic) BOOL lockInterfaceRotation;
@property (nonatomic) id runtimeErrorHandlingObserver;

@end

@implementation AVCamViewController

- (BOOL)isSessionRunningAndDeviceAuthorized
{
	return [[self session] isRunning] && [self isDeviceAuthorized];
}

+ (NSSet *)keyPathsForValuesAffectingSessionRunningAndDeviceAuthorized
{
	return [NSSet setWithObjects:@"session.running", @"deviceAuthorized", nil];
}

- (void)viewDidLoad
{
	[super viewDidLoad];
    
	[self templateStart];
	
	// Create the AVCaptureSession
	AVCaptureSession *session = [[AVCaptureSession alloc] init];
	[self setSession:session];
	
	// Setup the preview view
	[[self previewView] setSession:session];
	
	// Check for device authorization
	[self checkDeviceAuthorizationStatus];
	
	// In general it is not safe to mutate an AVCaptureSession or any of its inputs, outputs, or connections from multiple threads at the same time.
	// Why not do all of this on the main queue?
	// -[AVCaptureSession startRunning] is a blocking call which can take a long time. We dispatch session setup to the sessionQueue so that the main queue isn't blocked (which keeps the UI responsive).
	
	dispatch_queue_t sessionQueue = dispatch_queue_create("session queue", DISPATCH_QUEUE_SERIAL);
	[self setSessionQueue:sessionQueue];
	
	dispatch_async(sessionQueue, ^{
		[self setBackgroundRecordingID:UIBackgroundTaskInvalid];
		
		NSError *error = nil;
		
		AVCaptureDevice *videoDevice = [AVCamViewController deviceWithMediaType:AVMediaTypeVideo preferringPosition:AVCaptureDevicePositionBack];
		AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
		
		if (error)
		{
			NSLog(@"%@", error);
		}
		
		if ([session canAddInput:videoDeviceInput])
		{
			[session addInput:videoDeviceInput];
			//			[self setVideoDeviceInput:videoDeviceInput];
			
			dispatch_async(dispatch_get_main_queue(), ^{
				// Why are we dispatching this to the main queue?
				// Because AVCaptureVideoPreviewLayer is the backing layer for AVCamPreviewView and UIView can only be manipulated on main thread.
				// Note: As an exception to the above rule, it is not necessary to serialize video orientation changes on the AVCaptureVideoPreviewLayer’s connection with other session manipulation.
				
				[[(AVCaptureVideoPreviewLayer *)[[self previewView] layer] connection] setVideoOrientation:(AVCaptureVideoOrientation)[self interfaceOrientation]];
			});
		}
				
		AVCaptureStillImageOutput *stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
		if ([session canAddOutput:stillImageOutput])
		{
			[stillImageOutput setOutputSettings:@{AVVideoCodecKey : AVVideoCodecJPEG}];
			[session addOutput:stillImageOutput];
			[self setStillImageOutput:stillImageOutput];
		}
	});
    [self installVolume];
	[self toggleMode];
}

-(void)templateStart
{
	CGRect screen = [[UIScreen mainScreen] bounds];
	_gridView.frame = CGRectMake(0, 0, screen.size.width, screen.size.height);
	_gridView.backgroundColor = [UIColor clearColor];
	
	_loadingIndicator.backgroundColor = [UIColor whiteColor];
	_loadingIndicator.frame = CGRectMake(10, 10, 10, 10);
	_loadingIndicator.layer.cornerRadius = 5;
	
	_blackScreenView.frame = CGRectMake(0, 0, screen.size.width, screen.size.height);
	_blackScreenView.backgroundColor = [UIColor blackColor];
	
	
	_centerHorizontalGrid.backgroundColor = [UIColor colorWithWhite:1 alpha:1];
	_centerHorizontalGrid.frame = CGRectMake(screen.size.width/2, screen.size.height/2, 1, 1);
	
	_centerVerticalGrid.backgroundColor = [UIColor colorWithWhite:1 alpha:1];
	_centerVerticalGrid.frame = CGRectMake(screen.size.width/2, screen.size.height/2, 1, 1);
	
	_centerHorizontalGridSecondary1.backgroundColor = [UIColor colorWithWhite:1 alpha:0];
	_centerHorizontalGridSecondary1.frame = CGRectMake(0, 0, screen.size.width, 1);
	
	_centerHorizontalGridSecondary2.backgroundColor = [UIColor colorWithWhite:1 alpha:0];
	_centerHorizontalGridSecondary2.frame = CGRectMake( 0, screen.size.height, screen.size.width, 1);
	
	_centerVerticalGridSecondary1.backgroundColor = [UIColor colorWithWhite:1 alpha:0];
	_centerVerticalGridSecondary1.frame = CGRectMake(0, 0, 1, screen.size.height);
	
	_centerVerticalGridSecondary2.backgroundColor = [UIColor colorWithWhite:1 alpha:0];
	_centerVerticalGridSecondary2.frame = CGRectMake(screen.size.width, 0, 1, screen.size.height);
	
	_modeLabel.frame = CGRectMake(30, 0, screen.size.width-30, 30);
	_modeLabel.text = @"Ready";
	_modeLabel.alpha = 1;
	
	_modeButton.frame = CGRectMake(0, 0, screen.size.width, 60);
	
	[UIView beginAnimations: @"Splash Intro" context:nil];
	[UIView setAnimationDuration:0.5];
	[UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
	
	_blackScreenView.alpha = 0;
	
	_modeLabel.alpha = 0;
	
	_centerHorizontalGrid.backgroundColor = [UIColor colorWithWhite:1 alpha:0.3];
	_centerHorizontalGrid.frame = CGRectMake(0, screen.size.height/2, screen.size.width, 1);
	
	_centerVerticalGrid.backgroundColor = [UIColor colorWithWhite:1 alpha:0.3];
	_centerVerticalGrid.frame = CGRectMake(screen.size.width/2, 0, 1, screen.size.height);
	
	_centerHorizontalGridSecondary1.backgroundColor = [UIColor colorWithWhite:1 alpha:0.1];
	_centerHorizontalGridSecondary1.frame = CGRectMake(0, screen.size.height/3, screen.size.width, 1);
	
	_centerHorizontalGridSecondary2.backgroundColor = [UIColor colorWithWhite:1 alpha:0.1];
	_centerHorizontalGridSecondary2.frame = CGRectMake( 0, (screen.size.height/3)*2, screen.size.width, 1);
	
	_centerVerticalGridSecondary1.backgroundColor = [UIColor colorWithWhite:1 alpha:0.1];
	_centerVerticalGridSecondary1.frame = CGRectMake(screen.size.width/3, 0, 1, screen.size.height);
	
	_centerVerticalGridSecondary2.backgroundColor = [UIColor colorWithWhite:1 alpha:0.1];
	_centerVerticalGridSecondary2.frame = CGRectMake((screen.size.width/3)*2, 0, 1, screen.size.height);
	
	[UIView commitAnimations];
	
	
}

- (void)viewWillAppear:(BOOL)animated
{
	dispatch_async([self sessionQueue], ^{
		[self addObserver:self forKeyPath:@"sessionRunningAndDeviceAuthorized" options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:SessionRunningAndDeviceAuthorizedContext];
		[self addObserver:self forKeyPath:@"stillImageOutput.capturingStillImage" options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:CapturingStillImageContext];
		//		[self addObserver:self forKeyPath:@"movieFileOutput.recording" options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) context:RecordingContext];
		//		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(subjectAreaDidChange:) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:[[self videoDeviceInput] device]];
		
		__weak AVCamViewController *weakSelf = self;
		[self setRuntimeErrorHandlingObserver:[[NSNotificationCenter defaultCenter] addObserverForName:AVCaptureSessionRuntimeErrorNotification object:[self session] queue:nil usingBlock:^(NSNotification *note) {
			AVCamViewController *strongSelf = weakSelf;
			dispatch_async([strongSelf sessionQueue], ^{
				// Manually restarting the session since it must have been stopped due to an error.
				[[strongSelf session] startRunning];
				[[strongSelf recordButton] setTitle:NSLocalizedString(@"Record", @"Recording button record title") forState:UIControlStateNormal];
			});
		}]];
		[[self session] startRunning];
	});
}

- (void)viewDidDisappear:(BOOL)animated
{
	dispatch_async([self sessionQueue], ^{
		[[self session] stopRunning];
		
		//		[[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureDeviceSubjectAreaDidChangeNotification object:[[self videoDeviceInput] device]];
		[[NSNotificationCenter defaultCenter] removeObserver:[self runtimeErrorHandlingObserver]];
		
		[self removeObserver:self forKeyPath:@"sessionRunningAndDeviceAuthorized" context:SessionRunningAndDeviceAuthorizedContext];
		[self removeObserver:self forKeyPath:@"stillImageOutput.capturingStillImage" context:CapturingStillImageContext];
		[self removeObserver:self forKeyPath:@"movieFileOutput.recording" context:RecordingContext];
	});
}

- (BOOL)prefersStatusBarHidden
{
	return YES;
}

- (BOOL)shouldAutorotate
{
	// Disable autorotation of the interface when recording is in progress.
	return ![self lockInterfaceRotation];
}

- (NSUInteger)supportedInterfaceOrientations
{
	return UIInterfaceOrientationMaskAll;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	[[(AVCaptureVideoPreviewLayer *)[[self previewView] layer] connection] setVideoOrientation:(AVCaptureVideoOrientation)toInterfaceOrientation];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if (context == CapturingStillImageContext)
	{
		BOOL isCapturingStillImage = [change[NSKeyValueChangeNewKey] boolValue];
		
		if (isCapturingStillImage)
		{
			[self runStillImageCaptureAnimation];
		}
	}
	else if (context == RecordingContext)
	{
		BOOL isRecording = [change[NSKeyValueChangeNewKey] boolValue];
		
		dispatch_async(dispatch_get_main_queue(), ^{
			if (isRecording)
			{
				[[self cameraButton] setEnabled:NO];
				[[self recordButton] setTitle:NSLocalizedString(@"Stop", @"Recording button stop title") forState:UIControlStateNormal];
				[[self recordButton] setEnabled:YES];
			}
			else
			{
				[[self cameraButton] setEnabled:YES];
				[[self recordButton] setTitle:NSLocalizedString(@"Record", @"Recording button record title") forState:UIControlStateNormal];
				[[self recordButton] setEnabled:YES];
			}
		});
	}
	else if (context == SessionRunningAndDeviceAuthorizedContext)
	{
		BOOL isRunning = [change[NSKeyValueChangeNewKey] boolValue];
		
		dispatch_async(dispatch_get_main_queue(), ^{
			if (isRunning)
			{
				[[self cameraButton] setEnabled:YES];
				[[self recordButton] setEnabled:YES];
				[[self stillButton] setEnabled:YES];
			}
			else
			{
				[[self cameraButton] setEnabled:NO];
				[[self recordButton] setEnabled:NO];
				[[self stillButton] setEnabled:NO];
			}
		});
	}
	else
	{
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

#pragma mark Actions

- (IBAction)snapStillImage:(id)sender
{
	CGRect screen = [[UIScreen mainScreen] bounds];
	
	// Disallow Click
	if( isRendering == 1 ){
		[self displayModeMessage:@"wait"];
		return;
	}
	
	// Remove preview image
	if( self.previewThing.image != NULL ){
		[UIView beginAnimations: @"Splash Intro" context:nil];
		[UIView setAnimationDuration:1];
		[UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
		_blackScreenView.alpha = 0;
		_loadingIndicator.alpha = 1;
		[UIView commitAnimations];
		
		self.previewThing.image = NULL;
		
		[self displayModeMessage:@"picture"];
		return;
	}
	
	_blackScreenView.frame = CGRectMake(0, 0, screen.size.width, screen.size.height);
	_blackScreenView.alpha = 0;
	_previewThing.alpha = 0;
	
	// Animate
	[UIView beginAnimations: @"Splash Intro" context:nil];
	[UIView setAnimationDuration:0.5];
	[UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
	[UIView setAnimationDelay:1];
	_blackScreenView.alpha = 1;
	[UIView commitAnimations];
	
	// Save
	isRendering = 1;
	
	checkLooper = [NSTimer scheduledTimerWithTimeInterval:0.2 target:self selector:@selector(checkLoop) userInfo:nil repeats:YES];
	
	[[[self stillImageOutput] connectionWithMediaType:AVMediaTypeVideo] setVideoOrientation:AVCaptureVideoOrientationLandscapeLeft];
	
	[[self stillImageOutput] captureStillImageAsynchronouslyFromConnection:[[self stillImageOutput] connectionWithMediaType:AVMediaTypeVideo] completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
		
		if (imageDataSampleBuffer)
		{
			NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
			
			if(modeCurrent == 1){
				imageInMemory = [self greyMode:[[UIImage alloc] initWithData:imageData]];
			}
			else{
				imageInMemory = [self noirMode:[[UIImage alloc] initWithData:imageData]];
			}
			
			[self displayModeMessage:@"saved to albums"];
			
		}
	}];
}

-(void)displayModeMessage :(NSString*)message
{
	_modeLabel.alpha = 1;
	_modeLabel.text = message;
	
	[UIView beginAnimations: @"Splash Intro" context:nil];
	[UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
	[UIView setAnimationDelay:1];
	[UIView setAnimationDuration:0.5];
	_modeLabel.alpha = 0;
	_loadingIndicator.alpha = 1;
	[UIView commitAnimations];
}

-(void)checkLoop
{
	// Ready
	if( imageInMemory != NULL){
		
		[UIView beginAnimations: @"Splash Intro" context:nil];
		[UIView setAnimationDuration:2];
		[UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
		_previewThing.alpha = 1;
		[UIView commitAnimations];
		
		self.previewThing.image = imageInMemory;
		isRendering = 0;
		
		[self saveImage];
		imageInMemory = NULL;
		
		[checkLooper invalidate];
	}
}

-(void)saveImage
{
	[[[ALAssetsLibrary alloc] init] writeImageToSavedPhotosAlbum:[imageInMemory CGImage] orientation:(ALAssetOrientation)[imageInMemory imageOrientation] completionBlock:nil];
}


-(UIImage *) greyMode:(UIImage *)image {
    const int RED = 1, GREEN = 2, BLUE = 3;
	
    CGRect imageRect = CGRectMake(0, 0, image.size.width*2, image.size.height*2);
	
    int width = imageRect.size.width, height = imageRect.size.height;
	
    uint32_t * pixels = (uint32_t *) malloc(width*height*sizeof(uint32_t));
    memset(pixels, 0, width * height * sizeof(uint32_t));
	
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pixels, width, height, 8, width * sizeof(uint32_t), colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedLast);
	
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), [image CGImage]);
	
    for(int y = 0; y < height; y++) {
        for(int x = 0; x < width; x++) {
            uint8_t * rgbaPixel = (uint8_t *) &pixels[y*width+x];
            uint32_t gray = (0.333*rgbaPixel[RED]+0.333*rgbaPixel[GREEN]+0.333*rgbaPixel[BLUE]);
			
			// Remove contrast and push to white
			float whiteContent = (float)gray/255;
			gray = (gray * whiteContent * 0.85)+30;
			
			whiteContent = (float)gray/255;
			gray = gray + (whiteContent * 90.5);
			
			// Add a bit of Noise
			gray = gray + (5-arc4random_uniform(10));
			
			// Cap
			if(gray > 255){	gray = 255; }
			
            rgbaPixel[RED] = gray;
            rgbaPixel[GREEN] = gray;
            rgbaPixel[BLUE] = gray;
        }
    }
	
    CGImageRef newImage = CGBitmapContextCreateImage(context);
	
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    free(pixels);
	
    UIImage * resultUIImage = [UIImage imageWithCGImage:newImage scale:1 orientation:UIImageOrientationRight];
    CGImageRelease(newImage);
	
    return resultUIImage;
}

-(UIImage *) noirMode:(UIImage *)image {
    const int RED = 1, GREEN = 2, BLUE = 3;
	
    CGRect imageRect = CGRectMake(0, 0, image.size.width*2, image.size.height*2);
	
    int width = imageRect.size.width, height = imageRect.size.height;
	
    uint32_t * pixels = (uint32_t *) malloc(width*height*sizeof(uint32_t));
    memset(pixels, 0, width * height * sizeof(uint32_t));
	
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pixels, width, height, 8, width * sizeof(uint32_t), colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedLast);
	
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), [image CGImage]);
	
    for(int y = 0; y < height; y++) {
        for(int x = 0; x < width; x++) {
            uint8_t * rgbaPixel = (uint8_t *) &pixels[y*width+x];
            uint32_t gray = (0.333*rgbaPixel[RED]+0.333*rgbaPixel[GREEN]+0.333*rgbaPixel[BLUE]);
			
			// Remove contrast and push to white
			float whiteContent = (float)gray/255;
			gray = (gray * whiteContent * 0.95)-10;
			
			whiteContent = (float)gray/255;
			gray = gray + (whiteContent * 80.5)+20;
			
			// Add a bit of Noise
//			gray = gray + (5-arc4random_uniform(10));
			
			// Cap
			if(gray > 255){	gray = 255; }
			
            rgbaPixel[RED] = gray;
            rgbaPixel[GREEN] = gray;
            rgbaPixel[BLUE] = gray;
        }
    }
	
    CGImageRef newImage = CGBitmapContextCreateImage(context);
	
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    free(pixels);
	
    UIImage * resultUIImage = [UIImage imageWithCGImage:newImage scale:1 orientation:UIImageOrientationRight];
    CGImageRelease(newImage);
	
    return resultUIImage;
}

#pragma mark File Output Delegate

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error
{
	if (error)
		NSLog(@"%@", error);
	
	[self setLockInterfaceRotation:NO];
	
	// Note the backgroundRecordingID for use in the ALAssetsLibrary completion handler to end the background task associated with this recording. This allows a new recording to be started, associated with a new UIBackgroundTaskIdentifier, once the movie file output's -isRecording is back to NO — which happens sometime after this method returns.
	UIBackgroundTaskIdentifier backgroundRecordingID = [self backgroundRecordingID];
	[self setBackgroundRecordingID:UIBackgroundTaskInvalid];
	
	[[[ALAssetsLibrary alloc] init] writeVideoAtPathToSavedPhotosAlbum:outputFileURL completionBlock:^(NSURL *assetURL, NSError *error) {
		if (error)
			NSLog(@"%@", error);
		
		[[NSFileManager defaultManager] removeItemAtURL:outputFileURL error:nil];
		
		if (backgroundRecordingID != UIBackgroundTaskInvalid)
			[[UIApplication sharedApplication] endBackgroundTask:backgroundRecordingID];
	}];
}

#pragma mark Device Configuration

+ (AVCaptureDevice *)deviceWithMediaType:(NSString *)mediaType preferringPosition:(AVCaptureDevicePosition)position
{
	NSArray *devices = [AVCaptureDevice devicesWithMediaType:mediaType];
	AVCaptureDevice *captureDevice = [devices firstObject];
	
	for (AVCaptureDevice *device in devices)
	{
		if ([device position] == position)
		{
			captureDevice = device;
			break;
		}
	}
	
	return captureDevice;
}

#pragma mark UI

- (void)runStillImageCaptureAnimation
{
	dispatch_async(dispatch_get_main_queue(), ^{
		[[[self previewView] layer] setOpacity:0.0];
		[UIView animateWithDuration:.25 animations:^{
			[[[self previewView] layer] setOpacity:1.0];
		}];
	});
}

- (void)checkDeviceAuthorizationStatus
{
	NSString *mediaType = AVMediaTypeVideo;
	
	[AVCaptureDevice requestAccessForMediaType:mediaType completionHandler:^(BOOL granted) {
		if (granted)
		{
			//Granted access to mediaType
			[self setDeviceAuthorized:YES];
		}
		else
		{
			//Not granted access to mediaType
			dispatch_async(dispatch_get_main_queue(), ^{
				[[[UIAlertView alloc] initWithTitle:@"AVCam!"
											message:@"AVCam doesn't have permission to use Camera, please change privacy settings"
										   delegate:self
								  cancelButtonTitle:@"OK"
								  otherButtonTitles:nil] show];
				[self setDeviceAuthorized:NO];
			});
		}
	}];
}

#pragma mark Volume Button

/* Instructions:
 1. Add the Media player framework to your project.
 2. Insert following code into the controller for your shutter view.
 3. Add [self installVolume] to your viewdidload function
 4. add your shutter trigger code to the volumeChanged function
 5. Call uninstallVolume whenever you want to remove the volume changed notification
 
 note: If the user holds the volume+ button down, the volumeChanged function will be called repeatedly, be sure to add a rate limiter if your application isn't setup to take multiple photos a second.
 
 */



float currentVolume; //Current Volume

-(void)installVolume { /*Installs the volume button view and sets up the notifications to trigger the volumechange and the resetVolume button*/
    MPVolumeView *volumeView = [[MPVolumeView alloc] initWithFrame:CGRectMake(-100, -100, 1, 1)];
    volumeView.showsRouteButton = NO;
    [self.previewView addSubview:volumeView];
    [self.previewView sendSubviewToBack:volumeView];
    
    [self resetVolumeButton];
    
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(volumeChanged:)
     name:@"AVSystemController_SystemVolumeDidChangeNotification"
     object:nil];
    
    [[NSNotificationCenter defaultCenter]
     addObserver:self selector:@selector(resetVolumeButton) name:UIApplicationDidBecomeActiveNotification object:nil];
    
    
    
}

-(void)uninstallVolume { /*removes notifications, install when you are closing the app or the camera view*/
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"AVSystemController_SystemVolumeDidChangeNotification"
                                                  object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidBecomeActiveNotification
                                                  object:nil];
}

-(void)resetVolumeButton { /*gets the current volume and sets up the button, needs to be called when the app returns from background.*/
    currentVolume=-1;
    AVAudioPlayer* p = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"silence.wav"]] error:NULL];
    
    [p prepareToPlay];
    [p stop];
    
    MPMusicPlayerController *volumeGetter = [MPMusicPlayerController iPodMusicPlayer];
    
    currentVolume = volumeGetter.volume;
}

- (void)volumeChanged:(NSNotification *)notification{
    float volume = [[[notification userInfo] objectForKey:@"AVSystemController_AudioVolumeNotificationParameter"] floatValue];
    if( [[[notification userInfo]objectForKey:@"AVSystemController_AudioVolumeChangeReasonNotificationParameter"]isEqualToString:@"ExplicitVolumeChange"]) {
        if(volume>=currentVolume && volume>0) {
            /* Do shutter button stuff here!*/
            [self snapStillImage:self];
        }
    }
    currentVolume=volume;
}

- (IBAction)modeButton:(id)sender {
	
	[self toggleMode];
	
	[self audioPlayer:@"fx.click.wav"];
	
}


-(void)toggleMode
{
	if(modeCurrent == 1){
		
		modeCurrent = 0;
		
		[self displayModeMessage:@"noir"];
		
		[UIView beginAnimations: @"Splash Intro" context:nil];
		[UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
		[UIView setAnimationDuration:0.5];
		_loadingIndicator.backgroundColor = [UIColor colorWithWhite:0 alpha:1];
		[UIView commitAnimations];
	}
	else{
		
		modeCurrent = 1;
		[self displayModeMessage:@"clair"];
		
		[UIView beginAnimations: @"Splash Intro" context:nil];
		[UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
		[UIView setAnimationDuration:0.5];
		_loadingIndicator.backgroundColor = [UIColor colorWithWhite:1 alpha:1];
		[UIView commitAnimations];
	}
	
}

-(void)audioPlayer: (NSString *)filename;
{
	NSString *resourcePath = [[NSBundle mainBundle] resourcePath];
	resourcePath = [resourcePath stringByAppendingString: [NSString stringWithFormat:@"/%@", filename] ];
	NSError* err;
	audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL: [NSURL fileURLWithPath:resourcePath] error:&err];
	
	audioPlayer.volume = 0.5;
	audioPlayer.numberOfLoops = 0;
	audioPlayer.currentTime = 0;
	
	if(err)	{ NSLog(@"%@",err); }
	else	{
		[audioPlayer prepareToPlay];
		[audioPlayer play];
	}
}
	


@end
