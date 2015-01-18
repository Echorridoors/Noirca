//
//  NoirSharpFilter.m
//  noirca
//
//  Created by Patrick Winchell on 1/2/15.
//  Copyright (c) 2015 Apple Inc. All rights reserved.
//

#import "NoirSharpFilter.h"


NSString *const kNoirSharpVertexShaderString = SHADER_STRING
(
 attribute vec4 position;
 attribute vec4 inputTextureCoordinate;
 
 uniform float imageWidthFactor;
 uniform float imageHeightFactor;
 uniform float sharpness;
 
 varying vec2 textureCoordinate;
 varying vec2 leftTextureCoordinate;
 varying vec2 rightTextureCoordinate;
 varying vec2 topTextureCoordinate;
 varying vec2 bottomTextureCoordinate;
 
 varying float centerMultiplier;
 varying float edgeMultiplier;
 
 void main()
 {
     gl_Position = position;
     
     vec2 widthStep = vec2(imageWidthFactor, 0.0);
     vec2 heightStep = vec2(0.0, imageHeightFactor);
     
     textureCoordinate = inputTextureCoordinate.xy;
     leftTextureCoordinate = inputTextureCoordinate.xy - widthStep;
     rightTextureCoordinate = inputTextureCoordinate.xy + widthStep;
     topTextureCoordinate = inputTextureCoordinate.xy + heightStep;
     bottomTextureCoordinate = inputTextureCoordinate.xy - heightStep;
     
     centerMultiplier = 1.0 + 4.0 * sharpness;
     edgeMultiplier = .25;
 }
 );

NSString *const kNoirSharpFragmentShaderString = SHADER_STRING
(
 precision highp float;
 
 varying highp vec2 textureCoordinate;
 varying highp vec2 leftTextureCoordinate;
 varying highp vec2 rightTextureCoordinate;
 varying highp vec2 topTextureCoordinate;
 varying highp vec2 bottomTextureCoordinate;
 
 varying highp float centerMultiplier;
 varying highp float edgeMultiplier;
 
 uniform sampler2D inputImageTexture;
 
 void main()
 {
     mediump vec3 textureColor = texture2D(inputImageTexture, textureCoordinate).rgb;
     mediump vec3 leftTextureColor = texture2D(inputImageTexture, leftTextureCoordinate).rgb;
     mediump vec3 rightTextureColor = texture2D(inputImageTexture, rightTextureCoordinate).rgb;
     mediump vec3 topTextureColor = texture2D(inputImageTexture, topTextureCoordinate).rgb;
     mediump vec3 bottomTextureColor = texture2D(inputImageTexture, bottomTextureCoordinate).rgb;
     
     mediump vec3 average = (leftTextureColor * edgeMultiplier + rightTextureColor * edgeMultiplier + topTextureColor * edgeMultiplier + bottomTextureColor * edgeMultiplier);
     
     if(textureColor.r > average.r )
         textureColor = clamp(textureColor * 1.5 - average * 0.5,0.0,1.0);
     
     gl_FragColor = vec4((textureColor), texture2D(inputImageTexture, bottomTextureCoordinate).w);
 }
 );


@implementation NoirSharpFilter

#pragma mark -
#pragma mark Initialization and teardown

- (id)init;
{
    if (!(self = [super initWithVertexShaderFromString:kNoirSharpVertexShaderString fragmentShaderFromString:kNoirSharpFragmentShaderString]))
    {
        return nil;
    }
    
    
    
    imageWidthFactorUniform = [filterProgram uniformIndex:@"imageWidthFactor"];
    imageHeightFactorUniform = [filterProgram uniformIndex:@"imageHeightFactor"];
    
    return self;
}

- (void)setupFilterForSize:(CGSize)filterFrameSize;
{
    runSynchronouslyOnVideoProcessingQueue(^{
        [GPUImageContext setActiveShaderProgram:filterProgram];
        
        if (GPUImageRotationSwapsWidthAndHeight(inputRotation))
        {
            glUniform1f(imageWidthFactorUniform, 1.0 / filterFrameSize.height);
            glUniform1f(imageHeightFactorUniform, 1.0 / filterFrameSize.width);
        }
        else
        {
            glUniform1f(imageWidthFactorUniform, 1.0 / filterFrameSize.width);
            glUniform1f(imageHeightFactorUniform, 1.0 / filterFrameSize.height);
        }
    });
}

@end

