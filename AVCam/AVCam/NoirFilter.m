//
//  NoirFilter.m
//  noirca
//
//  Created by Patrick Winchell on 1/1/15.
//  Copyright (c) 2015 Apple Inc. All rights reserved.
//

#import "NoirFilter.h"

NSString *const noirFilter = SHADER_STRING
(
 varying highp vec2 textureCoordinate;
 uniform sampler2D inputImageTexture;
 
 void main()
{
    lowp vec4 textureColor = texture2D(inputImageTexture, textureCoordinate);
    
    lowp float gray = textureColor.r;
    gray = (gray * gray * 1.25) + .235;
    gray = (gray * 1.786) - 0.314;
    gray = clamp(gray,0.0,1.0);
    gl_FragColor = vec4(gray,gray,gray,1.0);
}
 );

/*
 uint8_t * rgbaPixel = (uint8_t *) &pixels[y*width+x];
 uint32_t gray = (0.0*rgbaPixel[RED]+0.0*rgbaPixel[GREEN]+0.9*rgbaPixel[BLUE]);
 
 float grayFloat = gray;
 
 float whiteContent = (float)grayFloat/255;
 
 grayFloat = (grayFloat * whiteContent * 1.25)+60;
 
 whiteContent = (float)grayFloat/255;
 grayFloat = grayFloat + (whiteContent * 200.5)-80;
 
 // Cap
 if(grayFloat > 255){ grayFloat = 255; }
 if(grayFloat < 0){ grayFloat = 00; }
 
 gray = (int)grayFloat;
 
 rgbaPixel[RED] = gray;
 rgbaPixel[GREEN] = gray;
 rgbaPixel[BLUE] = gray;
 */
 

@implementation NoirFilter

-(id)init {
    self = [self initWithFragmentShaderFromString:noirFilter];
    if (self) {
        
    }
    return self;
}

@end
