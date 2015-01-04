//
//  ScreenAspectRatioCropFilter.h
//  noirca
//
//  Created by Patrick Winchell on 1/1/15.
//  Copyright (c) 2015 Apple Inc. All rights reserved.
//
//  Crop filter that crops an image to the screen's size

#import "GPUImageCropFilter.h"

@interface ScreenAspectRatioCropFilter : GPUImageCropFilter
{
    CGSize lastInputSize;
}

@end
