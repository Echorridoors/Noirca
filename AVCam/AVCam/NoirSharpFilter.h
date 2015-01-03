//
//  NoirSharpFilter.h
//  noirca
//
//  Created by Patrick Winchell on 1/2/15.
//  Copyright (c) 2015 Apple Inc. All rights reserved.
//

#import "GPUImageFilter.h"

@interface NoirSharpFilter : GPUImageFilter
{
    GLint sharpnessUniform;
    GLint imageWidthFactorUniform, imageHeightFactorUniform;
}
@end
