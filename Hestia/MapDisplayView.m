//
//  MapDisplayView.m
//  Hestia
//
//  Created by Khaos Tian on 8/15/13.
//  Copyright (c) 2013 Oltica. All rights reserved.
//

#import "MapDisplayView.h"

@interface MapDisplayView ()
{
    NSData      *_mapData;
}

@end

@implementation MapDisplayView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        // Initialization code
    }
    return self;
}

- (void)setMapURL:(NSURL *)url
{
    _mapData = [NSData dataWithContentsOfURL:url];
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    
    // PDF might be transparent, assume white paper
    [[UIColor clearColor] set];
    CGContextFillRect(ctx, rect);
    
    // Flip coordinates
    CGContextGetCTM(ctx);
    CGContextScaleCTM(ctx, 1, -1);
    CGContextTranslateCTM(ctx, 0, -rect.size.height);
    if (_mapData) {
        // url is a file URL
        CGDataProviderRef dataProvider = CGDataProviderCreateWithCFData((CFDataRef)_mapData);
        CGPDFDocumentRef pdf = CGPDFDocumentCreateWithProvider(dataProvider);
        CGDataProviderRelease(dataProvider);
        CGPDFPageRef page1 = CGPDFDocumentGetPage(pdf, 1);
        
        // get the rectangle of the cropped inside
        CGRect mediaRect = CGPDFPageGetBoxRect(page1, kCGPDFCropBox);
        CGContextScaleCTM(ctx, rect.size.width / mediaRect.size.width,
                          rect.size.height / mediaRect.size.height);
        CGContextTranslateCTM(ctx, -mediaRect.origin.x, -mediaRect.origin.y);
        
        // draw it
        CGContextDrawPDFPage(ctx, page1);
        CGPDFDocumentRelease(pdf);
    }
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

@end
