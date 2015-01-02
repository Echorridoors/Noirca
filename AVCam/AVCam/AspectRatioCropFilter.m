//
//  AspectRatioCropFilter.m
//  noirca
//
//  Created by Patrick Winchell on 1/1/15.
//  Copyright (c) 2015 Apple Inc. All rights reserved.
//

#import "AspectRatioCropFilter.h"

@implementation AspectRatioCropFilter

- (void)setInputSize:(CGSize)newSize atIndex:(NSInteger)textureIndex;
{
    CGSize tempsize = newSize;
    if(newSize.width!=lastInputSize.width || newSize.height!=lastInputSize.height) {
        lastInputSize = newSize;
        CGSize screenSize =[[UIScreen mainScreen] bounds].size;
        
        float ratio = screenSize.width/screenSize.height;
        
        float currentRatio = newSize.width/newSize.height;
        
        if(currentRatio>ratio) {
            float newwidth = newSize.height*ratio;
            //rect.origin.x = (rect.size.width-newwidth)/2;
            newSize.width = newwidth;
        }
    }
    
    [super setInputSize:tempsize atIndex:textureIndex];
    
}

@end
