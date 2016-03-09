//
//  ImojiSDKUI
//
//  Created by Alex Hoang
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

#import <Masonry/Masonry.h>
#import "IMKeyboardView.h"
#import "IMKeyboardCollectionView.h"
#import "IMToolbar.h"
#import "IMAttributeStringUtil.h"
#import "IMConnectivityUtil.h"
#import "IMKeyboardSearchTextField.h"
#import "IMCollectionLoadingView.h"

NSString *const IMKeyboardViewDefaultFontFamily = @"Imoji-Regular";

@interface IMKeyboardView ()

@property(nonatomic, strong) IMImojiSession *session;

// Top bar
@property(nonatomic, strong) UILabel *titleLabel;
@property(nonatomic, strong) UIButton *closeButton;
@property(nonatomic, strong) UIImageView *heartImageView;
@property(nonatomic, strong) UIImageView *copiedImageView;
@property(nonatomic) BOOL closeButtonIsHidden;

// progress bar
@property(nonatomic, strong) UIProgressView *progressView;

@end

@implementation IMKeyboardView {
    NSAttributedString *_previousTitle;
}

- (instancetype)initWithSession:(IMImojiSession *)session {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        self.session = session;
        self.imageBundle = [NSBundle bundleWithPath:[[NSBundle bundleForClass:[self class]] pathForResource:@"ImojiKeyboardAssets" ofType:@"bundle"]];
        self.fontFamily = IMKeyboardViewDefaultFontFamily;
        self.closeButtonIsHidden = NO;

        [self setup];
    }

    return self;
}

- (void)setup {
    self.backgroundColor = [UIColor colorWithRed:248.0f / 255.0f green:248.0f / 255.0f blue:248.0f / 255.0f alpha:1];

    // custom progress bar
    self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
    self.progressView.progressTintColor = [UIColor colorWithRed:102.0f / 255.0f green:102.0f / 255.0f blue:102.0f / 255.0f alpha:1];
    self.progressView.trackTintColor = [UIColor colorWithRed:180.0f / 255.0f green:180.0f / 255.0f blue:180.0f / 255.0f alpha:1];
    [self.progressView setProgress:0.0f animated:NO];
    [self addSubview:self.progressView];
    [self.progressView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.mas_top).with.offset(0);
        make.left.equalTo(self.mas_left).with.offset(0);
        make.right.equalTo(self.mas_right).with.offset(0);
        make.height.equalTo(@(1));
    }];

    // title
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 0, 200, 44)];
    self.titleLabel.attributedText = [IMAttributeStringUtil attributedString:@"REACTIONS"
                                                                    withFont:[IMAttributeStringUtil defaultFontWithSize:14.0f]
                                                                       color:[UIColor colorWithRed:51.0f / 255.0f green:51.0f / 255.0f blue:51.0f / 255.0f alpha:1]
                                                                andAlignment:NSTextAlignmentLeft];
    self.titleLabel.font = [UIFont fontWithName:self.fontFamily size:14.f];
    [self addSubview:self.titleLabel];

    // close button
    self.closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.closeButton setImage:[UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/keyboard_search_clear.png", self.imageBundle.bundlePath]] forState:UIControlStateNormal];
    [self.closeButton addTarget:self action:@selector(closeCategory) forControlEvents:UIControlEventTouchUpInside];
    self.closeButton.hidden = YES;
    [self addSubview:self.closeButton];
    [self.closeButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.progressView.mas_bottom).with.offset(0);
        make.right.equalTo(self.mas_right).with.offset(-5);
        make.height.equalTo(@(36));
    }];

    // heart
    self.heartImageView = [[UIImageView alloc] initWithImage:[UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/keyboard_favorited.png", self.imageBundle.bundlePath]]];
    [self addSubview:self.heartImageView];
    self.heartImageView.hidden = YES;
    [self.heartImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.progressView.mas_bottom).with.offset(0);
        make.right.equalTo(self.mas_right).with.offset(-5);
        make.height.width.equalTo(@(36));
    }];

    // copied
    self.copiedImageView = [[UIImageView alloc] initWithImage:[UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/keyboard_copied.png", self.imageBundle.bundlePath]]];
    [self addSubview:self.copiedImageView];
    self.copiedImageView.hidden = YES;
    [self.copiedImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.progressView.mas_bottom).with.offset(0);
        make.right.equalTo(self.mas_right).with.offset(-5);
        make.height.width.equalTo(@(36));
    }];

    // collection view
    _collectionView = [IMKeyboardCollectionView imojiCollectionViewWithSession:self.session];
    self.collectionView.clipsToBounds = YES;
    [self.collectionView setShowsHorizontalScrollIndicator:NO];
    self.collectionView.loadingView.backgroundColor = self.backgroundColor;
    self.collectionView.renderingOptions = [IMImojiObjectRenderingOptions optionsWithRenderSize:IMImojiObjectRenderSizeThumbnail];
    self.collectionView.renderingOptions.renderAnimatedIfSupported = YES;

    [self addSubview:self.collectionView];

    [self.collectionView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.mas_top).with.offset(30);
        make.centerX.equalTo(self);
        make.right.equalTo(self.mas_right);
        make.left.equalTo(self.mas_left);
    }];

    [self.collectionView.loadingView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.collectionView);
    }];

    // toolbar
    [self setupKeyboardToolbar];

    if (!self.hasFullAccess) {
        [self.collectionView displaySplashOfType:IMCollectionViewSplashCellEnableFullAccess];
        self.titleLabel.attributedText = [IMAttributeStringUtil attributedString:@"REQUIRES FULL ACCESS"
                                                                        withFont:[IMAttributeStringUtil defaultFontWithSize:14.0f]
                                                                           color:[UIColor colorWithRed:51.0f / 255.0f green:51.0f / 255.0f blue:51.0f / 255.0f alpha:1]
                                                                    andAlignment:NSTextAlignmentLeft];
        self.titleLabel.font = [UIFont fontWithName:self.fontFamily size:14.f];
    } else if ([IMConnectivityUtil sharedInstance].hasConnectivity) {
        self.currentCategoryClassification = IMImojiSessionCategoryClassificationGeneric;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self.collectionView loadImojiCategories:self.currentCategoryClassification];
        });
    } else {
        [self.collectionView displaySplashOfType:IMCollectionViewSplashCellNoConnection];
        self.titleLabel.attributedText = [IMAttributeStringUtil attributedString:@"NO NETWORK CONNECTION"
                                                                        withFont:[IMAttributeStringUtil defaultFontWithSize:14.0f]
                                                                           color:[UIColor colorWithRed:51.0f / 255.0f green:51.0f / 255.0f blue:51.0f / 255.0f alpha:1]
                                                                    andAlignment:NSTextAlignmentLeft];
        self.titleLabel.font = [UIFont fontWithName:self.fontFamily size:14.f];
    }

    // search
    _searchView = [[UIView alloc] init];
    self.searchView.backgroundColor = [UIColor clearColor];
    [self addSubview:self.searchView];
    [self.searchView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.progressView.mas_bottom).with.offset(1);
        make.left.equalTo(self.mas_left).with.offset(0);
        make.right.equalTo(self.mas_right).with.offset(0);
        make.bottom.equalTo(self.mas_bottom);
    }];

    UIView *searchBar = [[UIView alloc] init];
    searchBar.backgroundColor = self.backgroundColor;
    [self.searchView addSubview:searchBar];
    [searchBar mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.searchView.mas_top).with.offset(0);
        make.left.equalTo(self.searchView.mas_left).with.offset(0);
        make.right.equalTo(self.searchView.mas_right).with.offset(0);
        make.height.equalTo(@(40));
    }];

    CALayer *bottomBorder = [CALayer layer];
    bottomBorder.frame = CGRectMake(0, 39.f, [[UIScreen mainScreen] applicationFrame].size.height, 1.0f);
    bottomBorder.backgroundColor = [UIColor colorWithRed:194 / 255.f green:194 / 255.f blue:194 / 255.f alpha:1].CGColor;
    [searchBar.layer addSublayer:bottomBorder];

    UIButton *searchCancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [searchCancelButton setTitle:@"CANCEL" forState:UIControlStateNormal];
    searchCancelButton.titleLabel.font = [UIFont fontWithName:self.fontFamily size:14.f];
    [searchCancelButton addTarget:self action:@selector(cancelSearch) forControlEvents:UIControlEventTouchUpInside];
    [searchCancelButton setTitleColor:[UIColor colorWithRed:193.f / 255.0f green:193.f / 255.0f blue:199 / 255.0f alpha:1] forState:UIControlStateNormal];
    [searchBar addSubview:searchCancelButton];
    [searchCancelButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(searchBar.mas_top).with.offset(0);
        make.right.equalTo(self.searchView.mas_right);
        make.height.equalTo(@(40));
        make.width.equalTo(@(80));
    }];

    _searchField = [[IMKeyboardSearchTextField alloc] init];
    self.searchField.font = [UIFont fontWithName:self.fontFamily size:14.f];
    [searchBar addSubview:self.searchField];
    [self.searchField mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(searchBar.mas_top).with.offset(0);
        make.left.equalTo(searchBar.mas_left).with.offset(15);
        make.right.equalTo(searchCancelButton.mas_left).with.offset(10);
        make.height.equalTo(@(40));
    }];

    self.searchView.hidden = YES;
}

- (void)setupKeyboardToolbar {
    _keyboardToolbar = [IMToolbar imojiToolbar];
    self.keyboardToolbar.backgroundColor = [UIColor clearColor];
    self.keyboardToolbar.clipsToBounds = YES;

    [self addSubview:self.keyboardToolbar];

    [self.keyboardToolbar mas_makeConstraints:^(MASConstraintMaker *make) {
        make.bottom.equalTo(self.mas_bottom);
        make.left.equalTo(self.mas_left);
        make.right.equalTo(self.mas_right);
        make.height.equalTo(@(IMToolbarDefaultButtonItemWidthAndHeight));
        make.top.equalTo(self.collectionView.mas_bottom);
    }];
    
    [self.keyboardToolbar addToolbarButtonWithType:IMToolbarButtonKeyboardNextKeyboard
                                             image:[UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/keyboard_globe.png", self.imageBundle.bundlePath]]
                                       activeImage:nil];

    [self.keyboardToolbar addToolbarButtonWithType:IMToolbarButtonSearch
                                             image:[UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/keyboard_search.png", self.imageBundle.bundlePath]]
                                       activeImage:[UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/keyboard_search_active.png", self.imageBundle.bundlePath]]
    ];

    [self.keyboardToolbar addToolbarButtonWithType:IMToolbarButtonRecents
                                             image:[UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/keyboard_recents.png", self.imageBundle.bundlePath]]
                                       activeImage:[UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/keyboard_recents_active.png", self.imageBundle.bundlePath]]
    ];

    [self.keyboardToolbar addToolbarButtonWithType:IMToolbarButtonTrending
                                             image:[UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/keyboard_trending.png", self.imageBundle.bundlePath]]
                                       activeImage:[UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/keyboard_trending_active.png", self.imageBundle.bundlePath]]
    ];

    [self.keyboardToolbar addToolbarButtonWithType:IMToolbarButtonReactions
                                             image:[UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/keyboard_reactions.png", self.imageBundle.bundlePath]]
                                       activeImage:[UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/keyboard_reactions_active.png", self.imageBundle.bundlePath]]
    ];

    [self.keyboardToolbar addToolbarButtonWithType:IMToolbarButtonArtist
                                             image:[UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/keyboard_artist.png", self.imageBundle.bundlePath]]
                                       activeImage:[UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/keyboard_artist_active.png", self.imageBundle.bundlePath]]
    ];

    [self.keyboardToolbar addToolbarButtonWithType:IMToolbarButtonCollection
                                             image:[UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/keyboard_collection.png", self.imageBundle.bundlePath]]
                                       activeImage:[UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/keyboard_collection_active.png", self.imageBundle.bundlePath]]
    ];

    [self.keyboardToolbar addToolbarButtonWithType:IMToolbarButtonKeyboardDelete
                                             image:[UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/keyboard_delete.png", self.imageBundle.bundlePath]]
                                       activeImage:nil
    ];
}

- (void)closeCategory {
    self.closeButton.hidden = YES;

    // check if keyboard is in search mode
    UIButton *tmpButton = (UIButton *) [self viewWithTag:1];
    if (tmpButton.selected) {
        self.searchView.hidden = NO;
        self.searchField.text = @"";
        return;
    }

    if (self.delegate && [self.delegate respondsToSelector:@selector(userDidCloseCategoryFromView:)]) {
        [self.delegate userDidCloseCategoryFromView:self];
    }

    if (self.currentCategoryClassification == IMImojiSessionCategoryClassificationGeneric) {
        self.titleLabel.attributedText = [IMAttributeStringUtil attributedString:@"REACTIONS"
                                                                        withFont:[IMAttributeStringUtil defaultFontWithSize:14.0f]
                                                                           color:[UIColor colorWithRed:51.0f / 255.0f green:51.0f / 255.0f blue:51.0f / 255.0f alpha:1]
                                                                    andAlignment:NSTextAlignmentLeft];
        self.titleLabel.font = [UIFont fontWithName:self.fontFamily size:14.f];
    } else if (self.currentCategoryClassification == IMImojiSessionCategoryClassificationArtist) {
        self.titleLabel.attributedText = [IMAttributeStringUtil attributedString:@"ARTIST"
                                                                        withFont:[IMAttributeStringUtil defaultFontWithSize:14.0f]
                                                                           color:[UIColor colorWithRed:51.0f / 255.0f green:51.0f / 255.0f blue:51.0f / 255.0f alpha:1]
                                                                    andAlignment:NSTextAlignmentLeft];
        self.titleLabel.font = [UIFont fontWithName:self.fontFamily size:14.f];
    } else {
        self.titleLabel.attributedText = [IMAttributeStringUtil attributedString:@"TRENDING"
                                                                        withFont:[IMAttributeStringUtil defaultFontWithSize:14.0f]
                                                                           color:[UIColor colorWithRed:51.0f / 255.0f green:51.0f / 255.0f blue:51.0f / 255.0f alpha:1]
                                                                    andAlignment:NSTextAlignmentLeft];
        self.titleLabel.font = [UIFont fontWithName:self.fontFamily size:14.f];
    }
}

- (void)cancelSearch {
    self.searchField.text = @"";
    self.searchView.hidden = YES;
}

- (void)updateTitleWithText:(NSString *)text hideCloseButton:(BOOL)isHidden {
    self.closeButton.hidden = isHidden;
    self.closeButtonIsHidden = isHidden;

    self.titleLabel.attributedText = [IMAttributeStringUtil attributedString:[text uppercaseString]
                                                                    withFont:[IMAttributeStringUtil defaultFontWithSize:14.0f]
                                                                       color:[UIColor colorWithRed:51.0f / 255.0f green:51.0f / 255.0f blue:51.0f / 255.0f alpha:1]
                                                                andAlignment:NSTextAlignmentLeft];
    self.titleLabel.font = [UIFont fontWithName:self.fontFamily size:14.f];
}

- (void)updateProgressBarWithValue:(CGFloat)progress {
    [self.progressView setProgress:progress animated:YES];
}

- (void)showPreviousTitle {
    self.titleLabel.attributedText = _previousTitle;
    self.titleLabel.font = [UIFont fontWithName:self.fontFamily size:14.f];
    self.copiedImageView.hidden = YES;
    self.heartImageView.hidden = YES;
    self.closeButton.hidden = self.closeButtonIsHidden;
}

- (void)showDownloadingImojiIndicator {
    if (![self.titleLabel.attributedText.string isEqual:@"COPIED TO CLIPBOARD"] && ![self.titleLabel.attributedText.string isEqual:@"DOWNLOADING ..."] && ![self.titleLabel.attributedText.string isEqual:@"SAVED TO COLLECTION"]) {
        _previousTitle = self.titleLabel.attributedText;
    }

    self.titleLabel.attributedText = [IMAttributeStringUtil attributedString:@"DOWNLOADING ..."
                                                                    withFont:[IMAttributeStringUtil defaultFontWithSize:14.0f]
                                                                       color:[UIColor colorWithRed:51.0f / 255.0f green:51.0f / 255.0f blue:51.0f / 255.0f alpha:1]
                                                                andAlignment:NSTextAlignmentLeft];
    self.titleLabel.font = [UIFont fontWithName:self.fontFamily size:14.f];
    self.closeButton.hidden = YES;
}

- (void)showFinishedDownloadedWithMessage:(NSString *)message {
    self.titleLabel.attributedText = [IMAttributeStringUtil attributedString:[message uppercaseString]
                                                                    withFont:[IMAttributeStringUtil defaultFontWithSize:14.0f]
                                                                       color:[UIColor colorWithRed:51.0f / 255.0f green:51.0f / 255.0f blue:51.0f / 255.0f alpha:1]
                                                                andAlignment:NSTextAlignmentLeft];
    self.titleLabel.font = [UIFont fontWithName:self.fontFamily size:14.f];

    self.copiedImageView.hidden = NO;
    [self performSelector:@selector(showPreviousTitle) withObject:self afterDelay:1.5];
}

- (void)showAddedToCollectionIndicator {
    if (![self.titleLabel.attributedText.string isEqual:@"COPIED TO CLIPBOARD"] && ![self.titleLabel.attributedText.string isEqual:@"DOWNLOADING ..."] && ![self.titleLabel.attributedText.string isEqual:@"SAVED TO COLLECTION"]) {
        _previousTitle = self.titleLabel.attributedText;
    }
    self.titleLabel.attributedText = [IMAttributeStringUtil attributedString:@"SAVED TO COLLECTION"
                                                                    withFont:[IMAttributeStringUtil defaultFontWithSize:14.0f]
                                                                       color:[UIColor colorWithRed:51.0f / 255.0f green:51.0f / 255.0f blue:51.0f / 255.0f alpha:1]
                                                                andAlignment:NSTextAlignmentLeft];
    self.titleLabel.font = [UIFont fontWithName:self.fontFamily size:14.f];

    self.closeButton.hidden = YES;
    self.heartImageView.hidden = NO;
    [self performSelector:@selector(showPreviousTitle) withObject:self afterDelay:1.5];
}

- (BOOL)hasFullAccess {
    return [UIPasteboard generalPasteboard] != nil;
}

+ (instancetype)imojiKeyboardViewWithSession:(IMImojiSession *)session {
    return [[IMKeyboardView alloc] initWithSession:session];
}

@end
