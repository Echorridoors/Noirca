//
//  AspectRatioCropFilter.m
//  noirca
//
//  Created by Patrick Winchell on 1/1/15.
//  Copyright (c) 2015 Apple Inc. All rights reserved.
//

#import "ScreenAspectRatioCropFilter.h"

@implementation ScreenAspectRatioCropFilter

- (void)setInputSize:(CGSize)newSize atIndex:(NSInteger)textureIndex;
{
    CGSize rotatedSize = [self rotatedSize:newSize forIndex:textureIndex];
    
    CGSize tempSize = rotatedSize;
    
    if(newSize.width!=lastInputSize.width || newSize.height!=lastInputSize.height) {
        lastInputSize = newSize;
            CGSize screenSize =[[UIScreen mainScreen] bounds].size;
            
            float ratio = screenSize.width/screenSize.height;
            
            float currentRatio = rotatedSize.width/rotatedSize.height;
            
            if(currentRatio>ratio) {
                float newwidth = rotatedSize.height*ratio;
                rotatedSize.width = ceil(newwidth);
                float start = (tempSize.width-rotatedSize.width)/(tempSize.width*2);
                self.cropRegion = CGRectMake(start, 0, 1.0 - (start*2), 1.0);
            }
    }
    
    [super setInputSize:newSize atIndex:textureIndex];
    
}

@end
