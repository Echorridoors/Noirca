//
//  AspectRatioCropFilter.h
//  noirca
//
//  Created by Patrick Winchell on 1/1/15.
//  Copyright (c) 2015 Apple Inc. All rights reserved.
//

#import "GPUImageCropFilter.h"

@interface AspectRatioCropFilter : GPUImageCropFilter
{
    CGSize lastInputSize;
}

@end
