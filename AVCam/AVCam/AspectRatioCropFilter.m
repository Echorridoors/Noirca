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
    CGSize tempSize = newSize;
    if(newSize.width!=lastInputSize.width || newSize.height!=lastInputSize.height) {
        lastInputSize = newSize;
        CGSize screenSize =[[UIScreen mainScreen] bounds].size;
        
        float ratio = screenSize.width/screenSize.height;
        
        float currentRatio = newSize.width/newSize.height;
        
        if(currentRatio>ratio) {
            float newwidth = newSize.height*ratio;
            //rect.origin.x = (rect.size.width-newwidth)/2;
            newSize.width = newwidth;
            
            self.cropRegion = CGRectMake(0.0+(tempSize.width-newSize.width)/(tempSize.width*2), 0, (newSize.width)/(tempSize.width), 1.0);
        }
    }
    
    [super setInputSize:tempSize atIndex:textureIndex];
    
}

@end
