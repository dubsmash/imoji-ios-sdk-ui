//
//  ImojiSDKUI
//
//  Created by Nima Khoshini
//  Copyright (C) 2015 Imoji
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to
//  deal in the Software without restriction, including without limitation the
//  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
//  sell copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//

#import "IMCategoryCollectionViewCell.h"
#import <Masonry/View+MASAdditions.h>
#import <YYImage/YYAnimatedImageView.h>
#import "IMResourceBundleUtil.h"
#import "IMAttributeStringUtil.h"

NSString *const IMCategoryCollectionViewCellReuseId = @"IMCategoryCollectionViewCellReuseId";

@implementation IMCategoryCollectionViewCell {

}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];

        self.imojiView = [YYAnimatedImageView new];

        self.titleView = [UILabel new];
        self.titleView.font = [IMAttributeStringUtil defaultFontWithSize:14.0f];
        self.titleView.textColor = [UIColor colorWithWhite:.4f alpha:1.0f];
        self.titleView.numberOfLines = 2;
        self.titleView.textAlignment = NSTextAlignmentCenter;
        self.titleView.lineBreakMode = NSLineBreakByWordWrapping;

        [self addSubview:self.imojiView];
        [self addSubview:self.titleView];

        [self.imojiView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self);
            make.centerX.equalTo(self);
            make.height.width.equalTo(self.mas_height).multipliedBy(.70f);
        }];

        [self.titleView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.width.equalTo(self).multipliedBy(.75f);
            make.centerX.equalTo(self);
            make.top.equalTo(self.imojiView.mas_bottom);
            make.height.equalTo(@(self.titleView.font.lineHeight * 2.0f + 1.0f));
        }];
    }

    return self;
}

- (void)loadImojiCategory:(NSString *)categoryTitle imojiImojiImage:(UIImage *)imojiImage {
    [self loadImojiCategory:categoryTitle imojiImojiImage:imojiImage animated:YES];
}

- (void)loadImojiCategory:(NSString *)categoryTitle imojiImojiImage:(UIImage *)imojiImage animated:(BOOL)animated {
    BOOL showAnimations = animated && imojiImage != nil && !_hasImojiImage;

    if (imojiImage) {
        self.imojiView.image = imojiImage;
        self.imojiView.highlightedImage = [self tintImage:imojiImage withColor:[UIColor colorWithRed:0 green:0 blue:0 alpha:0.6f]];
        self.imojiView.contentMode = UIViewContentModeScaleAspectFit;

        _hasImojiImage = YES;

        if (showAnimations) {
            self.imojiView.transform = CGAffineTransformMakeScale(.2f, .2f);
        }
    } else {
        self.imojiView.image = [IMResourceBundleUtil loadingPlaceholderImageWithRadius:30];
        self.imojiView.highlightedImage = self.imojiView.image;
        self.imojiView.contentMode = UIViewContentModeCenter;

        _hasImojiImage = NO;
    }

    self.titleView.text = categoryTitle;

    if (showAnimations) {
        [self performLoadedAnimation];
    }
}

- (void)performLoadedAnimation {
    // animate immediately in iOS 7,
    BOOL animateImmediately = ![self respondsToSelector:@selector(preferredLayoutAttributesFittingAttributes:)];
    
    self.imojiView.transform = CGAffineTransformMakeScale(.2f, .2f);
    void (^animationBlock)() = ^ {
        [UIView animateWithDuration:.5f
                              delay:0
             usingSpringWithDamping:1.0f
              initialSpringVelocity:1.0f
                            options:UIViewAnimationOptionCurveEaseIn
                         animations:^{
                             self.imojiView.transform = CGAffineTransformIdentity;
                         }
                         completion:nil];
    };
    
    if (animateImmediately) {
        animationBlock();
    } else {
        dispatch_async(dispatch_get_main_queue(), animationBlock);
    }
}

- (UIImage *)tintImage:(UIImage *)image withColor:(UIColor *)tintColor {
    UIGraphicsBeginImageContextWithOptions(image.size, NO, image.scale);
    CGRect drawRect = CGRectMake(0, 0, image.size.width, image.size.height);
    [image drawInRect:drawRect];
    [tintColor set];
    UIRectFillUsingBlendMode(drawRect, kCGBlendModeSourceAtop);
    UIImage *tintedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return tintedImage;
}

@end
