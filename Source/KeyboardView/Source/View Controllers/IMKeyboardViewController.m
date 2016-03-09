//
//  ImojiSDKUI
//
//  Created by Jeff Wang
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
#import "IMKeyboardViewController.h"
#import "IMKeyboardCollectionView.h"
#import "IMQwertyViewController.h"
#import "IMToolbar.h"
#import "IMKeyboardView.h"

@interface IMKeyboardViewController () <IMQwertyViewControllerDelegate, IMImojiSessionDelegate, IMKeyboardViewDelegate,
        IMKeyboardCollectionViewDelegate, IMToolbarDelegate>

// keyboard view
@property(nonatomic, strong) IMKeyboardView *keyboardView;

// keyboard size
@property(nonatomic) CGFloat portraitHeight;
@property(nonatomic) CGFloat landscapeHeight;
@property(nonatomic) NSLayoutConstraint *heightConstraint;

// toolbar collection view switching variables
@property(nonatomic) BOOL isViewingImojiCategory;
@property(nonatomic) IMToolbarButtonType currentToolbarButtonSelected;

@end

@implementation IMKeyboardViewController {
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self setupKeyboardWithSession:[IMImojiSession imojiSession]];
    }

    return self;
}

- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        [self setupKeyboardWithSession:[IMImojiSession imojiSession]];
    }

    return self;
}


- (id)initWithImojiSession:(IMImojiSession *)session {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        [self setupKeyboardWithSession:session];
    }

    return self;
}

- (void)setupKeyboardWithSession:(IMImojiSession *)session {
    self.portraitHeight = IMKeyboardViewPortraitHeight;
    self.landscapeHeight = IMKeyboardViewLandscapeHeight;
    self.isViewingImojiCategory = NO;
    self.currentToolbarButtonSelected = IMToolbarButtonReactions;

    _session = session;
    _session.delegate = self;
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id <UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [self updateViewConstraints];
}

- (void)updateViewConstraints {
    [super updateViewConstraints];

    // Add custom view sizing constraints here
    if (self.view.frame.size.width == 0 || self.view.frame.size.height == 0) {
        return;
    }

    [self.inputView removeConstraint:self.heightConstraint];
    CGSize screenSize = [[UIScreen mainScreen] bounds].size;
    CGFloat screenH = screenSize.height;
    CGFloat screenW = screenSize.width;
    BOOL isLandscape = self.view.frame.size.width != (screenW * (screenW < screenH)) + (screenH * (screenW > screenH));

    if (isLandscape) {
        self.heightConstraint.constant = self.landscapeHeight;
        [self.inputView addConstraint:self.heightConstraint];
    } else {
        self.heightConstraint.constant = self.portraitHeight;
        [self.inputView addConstraint:self.heightConstraint];
    }

    [self.keyboardView.collectionView reloadData];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    if (!self.keyboardView) {
        // Constraints
        self.heightConstraint = [NSLayoutConstraint constraintWithItem:self.inputView
                                                             attribute:NSLayoutAttributeHeight
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:nil
                                                             attribute:NSLayoutAttributeNotAnAttribute
                                                            multiplier:0.0
                                                              constant:IMKeyboardViewPortraitHeight];
        self.heightConstraint.priority = UILayoutPriorityRequired - 1; // This will eliminate the constraint conflict warning.

        // View setup
        self.keyboardView = [IMKeyboardView imojiKeyboardViewWithSession:self.session];
        self.keyboardView.delegate = self;
        self.keyboardView.collectionView.collectionViewDelegate = self;
        self.keyboardView.keyboardToolbar.delegate = self;

        [self.view addSubview:self.keyboardView];

        [self.keyboardView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(self.view);
        }];

        // Assign qwerty controller to searchView
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"IMQwerty" bundle:[NSBundle mainBundle]];
        IMQwertyViewController *vc = (IMQwertyViewController *) [storyboard instantiateInitialViewController];

        vc.searchField = self.keyboardView.searchField;
        vc.delegate = self;

        [self addChildViewController:vc];
        [self.keyboardView.searchView addSubview:vc.view];

        [vc didMoveToParentViewController:self];
        [vc.view mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self.keyboardView.searchField.mas_bottom).with.offset(0);
            make.left.equalTo(self.keyboardView.mas_left).with.offset(0);
            make.right.equalTo(self.keyboardView.mas_right).with.offset(0);
            make.bottom.equalTo(self.keyboardView.mas_bottom);
        }];
    }

    [self.keyboardView.keyboardToolbar selectButtonOfType:IMToolbarButtonReactions];
}

#pragma mark IMQwertyViewControllerDelegate

- (void)userDidPressReturnKey {
    if (self.keyboardView.searchField.text.length > 0) {
        self.keyboardView.searchView.hidden = YES;

        [self.keyboardView updateTitleWithText:self.keyboardView.searchField.text hideCloseButton:NO];
        [self.keyboardView.collectionView loadImojisFromSearch:self.keyboardView.searchField.text];
    }
}

#pragma mark IMKeyboardViewDelegate

- (void)userDidCloseCategoryFromView:(IMKeyboardView *)view {
    self.isViewingImojiCategory = NO;

    // Display previous category
    [view.collectionView loadImojiCategories:view.currentCategoryClassification];
}

#pragma mark IMKeyboardCollectionViewDelegate

- (void)userDidSelectCategory:(IMImojiCategoryObject *)category fromCollectionView:(IMCollectionView *)collectionView {
    self.isViewingImojiCategory = YES;
    [self.keyboardView updateTitleWithText:category.title hideCloseButton:NO];
    [self.keyboardView.collectionView loadImojisFromCategory:category];
}

- (void)userDidSelectImoji:(IMImojiObject *)imoji fromCollectionView:(IMCollectionView *)collectionView {
    [self.keyboardView showDownloadingImojiIndicator];

    IMImojiObjectRenderingOptions *renderOptions;

    if (imoji.supportsAnimation) {
        renderOptions = [IMImojiObjectRenderingOptions optionsWithRenderSize:IMImojiObjectRenderSizeThumbnail];
    } else {
        renderOptions = [IMImojiObjectRenderingOptions optionsWithRenderSize:IMImojiObjectRenderSizeFullResolution];
        renderOptions.aspectRatio = [NSValue valueWithCGSize:CGSizeMake(16.0f, 9.0f)];
        renderOptions.maximumRenderSize = [NSValue valueWithCGSize:CGSizeMake(800.0f, 800.0f)];
    }
    renderOptions.renderAnimatedIfSupported = YES;

    [self.session renderImojiForExport:imoji
                               options:renderOptions
                              callback:^(UIImage *image, NSData *data, NSString *typeIdentifier, NSError *error) {
                                  if (error || !data) {
                                      NSLog(@"Error: %@", error);
                                      [self.keyboardView showFinishedDownloadedWithMessage:@"UNABLE TO DOWNLOAD IMOJI"];
                                  } else {
                                      UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
                                      pasteboard.persistent = YES;
                                      [pasteboard setData:data forPasteboardType:typeIdentifier];
                                      [self.keyboardView showFinishedDownloadedWithMessage:@"COPIED TO CLIPBOARD"];
                                  }

                              }];

    // save to recents
    [self saveToRecents:imoji];
}


- (void)userDidDoubleTapImoji:(IMImojiObject *)imoji fromCollectionView:(IMCollectionView *)collectionView {
    [self saveToFavorites:imoji];
    [self.keyboardView showAddedToCollectionIndicator];
}

- (void)userDidSelectSplash:(IMCollectionViewSplashCellType)splashType fromCollectionView:(IMCollectionView *)collectionView {
    if (splashType == IMCollectionViewSplashCellNoResults) {
        self.keyboardView.searchView.hidden = NO;
        [self.keyboardView updateProgressBarWithValue:0.f];
    }
}

- (void)imojiCollectionView:(IMCollectionView *)collectionView didFinishLoadingContentType:(IMCollectionViewContentType)contentType {
    UICollectionViewFlowLayout *layout = (UICollectionViewFlowLayout *) collectionView.collectionViewLayout;
    CGFloat progress;
    if (layout.scrollDirection == UICollectionViewScrollDirectionHorizontal) {
        progress = (collectionView.contentOffset.x + collectionView.frame.size.width) / collectionView.collectionViewLayout.collectionViewContentSize.width;
    } else {
        progress = (collectionView.contentOffset.y + collectionView.frame.size.height) / collectionView.collectionViewLayout.collectionViewContentSize.height;
    }

    if (progress != INFINITY) {
        [self.keyboardView updateProgressBarWithValue:progress];
    }
}

- (void)imojiCollectionViewDidScroll:(IMCollectionView *)collectionView {
    UICollectionViewFlowLayout *layout = (UICollectionViewFlowLayout *) collectionView.collectionViewLayout;
    CGFloat progress;
    if (layout.scrollDirection == UICollectionViewScrollDirectionHorizontal) {
        progress = (collectionView.contentOffset.x + collectionView.frame.size.width) / collectionView.contentSize.width;
    } else {
        progress = (collectionView.contentOffset.y + collectionView.frame.size.height) / collectionView.contentSize.height;
    }

    if (progress != INFINITY) {
        [self.keyboardView updateProgressBarWithValue:progress];
    }
}

- (void)userDidSelectAttributionLink:(NSURL *)attributionLink fromCollectionView:(IMCollectionView *)collectionView {
    UIResponder *responder = self;
    while ((responder = [responder nextResponder]) != nil) {
        if ([responder respondsToSelector:@selector(openURL:)]) {
            [responder performSelector:@selector(openURL:)
                            withObject:attributionLink];
        }
    }
}

#pragma mark IMToolbarDelegate

- (void)userDidSelectToolbarButton:(IMToolbarButtonType)buttonType {
    switch (buttonType) {
        case IMToolbarButtonKeyboardDelete:
            [self.textDocumentProxy deleteBackward];
            break;

        case IMToolbarButtonKeyboardNextKeyboard:
            [self advanceToNextInputMode];
            break;

        case IMToolbarButtonSearch:
            self.keyboardView.searchView.hidden = NO;
            [self.keyboardView updateProgressBarWithValue:0.f];
            break;
        case IMToolbarButtonRecents:
            [self.keyboardView.collectionView loadRecentImojis:self.recentImojis];
            [self.keyboardView updateTitleWithText:@"RECENTS" hideCloseButton:YES];
            break;
        case IMToolbarButtonReactions:
            if (self.isViewingImojiCategory || buttonType != self.currentToolbarButtonSelected) {
                self.isViewingImojiCategory = NO;

                // Set classification for use in returning user to Reactions when closing a category
                self.keyboardView.currentCategoryClassification = IMImojiSessionCategoryClassificationGeneric;

                [self.keyboardView.collectionView loadImojiCategories:IMImojiSessionCategoryClassificationGeneric];
                [self.keyboardView updateTitleWithText:@"REACTIONS" hideCloseButton:YES];
            }
            break;
        case IMToolbarButtonTrending:
            if (self.isViewingImojiCategory || buttonType != self.currentToolbarButtonSelected) {
                self.isViewingImojiCategory = NO;

                // Set classification for use in returning user to Trending when closing a category
                self.keyboardView.currentCategoryClassification = IMImojiSessionCategoryClassificationTrending;

                [self.keyboardView.collectionView loadImojiCategories:IMImojiSessionCategoryClassificationTrending];
                [self.keyboardView updateTitleWithText:@"TRENDING" hideCloseButton:YES];
            }
            break;
        case IMToolbarButtonArtist:
            if (self.isViewingImojiCategory || buttonType != self.currentToolbarButtonSelected) {
                self.isViewingImojiCategory = NO;

                // Set classification for use in returning user to Trending when closing a category
                self.keyboardView.currentCategoryClassification = IMImojiSessionCategoryClassificationArtist;

                [self.keyboardView.collectionView loadImojiCategories:IMImojiSessionCategoryClassificationArtist];
                [self.keyboardView updateTitleWithText:@"ARTIST" hideCloseButton:YES];
            }
            break;
        case IMToolbarButtonCollection: {
            [self.keyboardView.collectionView loadFavoriteImojis:self.favoritedImojis];
            [self.keyboardView updateTitleWithText:@"COLLECTION" hideCloseButton:YES];
            break;
        }
        default:
            break;
    }

    self.currentToolbarButtonSelected = buttonType;
}

#pragma mark Recents/Favorites Logic

- (void)saveToRecents:(IMImojiObject *)imojiObject {
    NSUInteger arrayCapacity = 20;
    NSUserDefaults *shared = [[NSUserDefaults alloc] initWithSuiteName:self.appGroup];
    NSArray *savedArrayOfRecents = [shared objectForKey:@"recentImojis"];
    NSMutableArray *arrayOfRecents = [NSMutableArray arrayWithCapacity:arrayCapacity];

    if (!savedArrayOfRecents || savedArrayOfRecents.count == 0) {
        [arrayOfRecents addObject:imojiObject.identifier];
    } else {
        [arrayOfRecents addObjectsFromArray:savedArrayOfRecents];

        if ([arrayOfRecents containsObject:imojiObject.identifier]) {
            [arrayOfRecents removeObject:imojiObject.identifier];
        }
        [arrayOfRecents insertObject:imojiObject.identifier atIndex:0];

        while (arrayOfRecents.count > arrayCapacity) {
            [arrayOfRecents removeLastObject];
        }
    }

    [shared setObject:arrayOfRecents forKey:@"recentImojis"];
    [shared synchronize];
}

- (void)saveToFavorites:(IMImojiObject *)imojiObject {
    if (self.session.sessionState == IMImojiSessionStateConnectedSynchronized) {
        [self.session addImojiToUserCollection:imojiObject
                                      callback:^(BOOL successful, NSError *error) {

                                      }];
    } else {
        NSUInteger arrayCapacity = 20;
        NSUserDefaults *shared = [[NSUserDefaults alloc] initWithSuiteName:self.appGroup];
        NSArray *savedArrayOfFavorites = [shared objectForKey:@"favoriteImojis"];
        NSMutableArray *arrayOfFavorites = [NSMutableArray arrayWithCapacity:arrayCapacity];

        if (!savedArrayOfFavorites || savedArrayOfFavorites.count == 0) {
            [arrayOfFavorites addObject:imojiObject.identifier];
        } else {
            [arrayOfFavorites addObjectsFromArray:savedArrayOfFavorites];

            if ([arrayOfFavorites containsObject:imojiObject.identifier]) {
                [arrayOfFavorites removeObject:imojiObject.identifier];
            }
            [arrayOfFavorites insertObject:imojiObject.identifier atIndex:0];

            while (arrayOfFavorites.count > arrayCapacity) {
                [arrayOfFavorites removeLastObject];
            }
        }

        [shared setObject:arrayOfFavorites forKey:@"favoriteImojis"];
        [shared synchronize];
    }
}

- (NSArray *)recentImojis {
    NSUserDefaults *shared = [[NSUserDefaults alloc] initWithSuiteName:self.appGroup];
    return [shared objectForKey:@"recentImojis"];
}

- (NSArray *)favoritedImojis {
    NSUserDefaults *shared = [[NSUserDefaults alloc] initWithSuiteName:self.appGroup];
    return [shared objectForKey:@"favoriteImojis"];
}

@end
