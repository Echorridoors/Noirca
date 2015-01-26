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
    
    lowp float gray = (textureColor.r) * .5;
    gray = (gray * gray * 1.15) + .435;
    gray = (gray * 1.486) - 0.514;
    
    gray = gray * (gray + 0.5);
    gray = clamp(gray,0.0,1.0);
    
    gl_FragColor = vec4(gray,gray,gray,1.0);
}
 );

@implementation NoirFilter

-(id)init {
    self = [self initWithFragmentShaderFromString:noirFilter];
    if (self) {
        
    }
    return self;
}

@end
