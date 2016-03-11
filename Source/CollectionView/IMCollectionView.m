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

#import <ImojiSDK/ImojiSDK.h>
#import <Masonry/Masonry.h>
#import "IMCollectionView.h"
#import "IMCollectionViewCell.h"
#import "IMCategoryCollectionViewCell.h"
#import "IMCollectionViewStatusCell.h"
#import "IMResourceBundleUtil.h"
#import "IMConnectivityUtil.h"
#import "IMCollectionReusableAttributionView.h"
#import "IMArtist.h"
#import "IMCollectionReusableHeaderView.h"
#import "IMCategoryAttribution.h"
#import "IMCollectionLoadingView.h"

NSUInteger const IMCollectionViewNumberOfItemsToLoad = 60;
CGFloat const IMCollectionReusableHeaderViewDefaultHeight = 49.0f;
CGFloat const IMCollectionReusableAttributionViewDefaultHeight = 187.0f;

@interface IMCollectionView () <IMCollectionReusableAttributionViewDelegate>

@property(nonatomic, strong) NSMutableArray *images;
@property(nonatomic, strong) NSMutableArray *content;
@property(nonatomic, strong) NSMutableArray *pendingCollectionViewUpdates;
@property(nonatomic, strong) UITapGestureRecognizer *tapGesture;
@property(nonatomic, strong) NSObject *loadingIndicatorObject;
@property(nonatomic, strong) NSOperation *imojiOperation;

@property(nonatomic, copy) NSString *currentSearchTerm;
@property(nonatomic, copy) NSString *currentHeader;
@property(nonatomic, copy) NSString *followUpSearchTerm;
@property(nonatomic, strong) IMCategoryAttribution *currentAttribution;
@property(nonatomic, strong) UIImage *artistPicture;

@property(nonatomic) BOOL shouldShowAttribution;
@property(nonatomic) BOOL shouldLoadNewSection;

@end

@implementation IMCollectionView {

}

- (instancetype)initWithSession:(IMImojiSession *)session {
    self = [super initWithFrame:CGRectZero collectionViewLayout:[UICollectionViewFlowLayout new]];
    if (self) {
        _session = session;
        _loadingIndicatorObject = [NSObject new];
        _imagesBundle = [IMResourceBundleUtil assetsBundle];
        _renderingOptions = session.fetchRenderingOptions;
        _preferredImojiDisplaySize = CGSizeMake(100.f, 100.f);
        _animateSelection = YES;
        _shouldShowAttribution = NO;
        _infiniteScroll = NO;
        _currentHeader = @"";

        self.dataSource = self;
        self.delegate = self;

        self.numberOfImojisToLoad = IMCollectionViewNumberOfItemsToLoad;

        self.backgroundColor = [UIColor whiteColor];

        self.content = [NSMutableArray array];
        self.images = [NSMutableArray array];
        self.pendingCollectionViewUpdates = [NSMutableArray array];

        self.tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                  action:@selector(userTappedSplashView:)];
        self.tapGesture.enabled = NO;
        [self addGestureRecognizer:self.tapGesture];

        if (NSFoundationVersionNumber >= NSFoundationVersionNumber_iOS_8_0) {
            self.loadingView = [[IMCollectionLoadingView alloc] initWithFrame:CGRectZero];
            self.loadingView.backgroundColor = self.backgroundColor;

            [self addSubview:self.loadingView];

            [self.loadingView mas_makeConstraints:^(MASConstraintMaker *make) {
                make.width.and.height.equalTo(self);
            }];
        }

        [self registerClass:[IMCollectionViewCell class] forCellWithReuseIdentifier:IMCollectionViewCellReuseId];
        [self registerClass:[IMCategoryCollectionViewCell class] forCellWithReuseIdentifier:IMCategoryCollectionViewCellReuseId];
        [self registerClass:[IMCollectionViewStatusCell class] forCellWithReuseIdentifier:IMCollectionViewStatusCellReuseId];
        [self registerClass:[IMCollectionViewSplashCell class] forCellWithReuseIdentifier:IMCollectionViewSplashCellReuseId];
        [self registerClass:[IMCollectionReusableHeaderView class] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:IMCollectionReusableHeaderViewReuseId];
        [self registerClass:[IMCollectionReusableAttributionView class] forSupplementaryViewOfKind:UICollectionElementKindSectionFooter withReuseIdentifier:IMCollectionReusableAttributionViewReuseId];
    }

    return self;
}

#pragma mark UICollectionViewDataSource

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return self.content.count;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return [self.content[(NSUInteger) section][@"imojis"] count];
}

- (NSInteger)numberOfSections {
    return [self numberOfSectionsInCollectionView:self];
}

- (NSInteger)numberOfItemsInSection:(NSInteger)section {
    return [self collectionView:self numberOfItemsInSection:section];
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    if (kind == UICollectionElementKindSectionHeader) {
        IMCollectionReusableHeaderView *headerView = (IMCollectionReusableHeaderView *) [self dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                                                                                                                 withReuseIdentifier:IMCollectionReusableHeaderViewReuseId
                                                                                                                        forIndexPath:indexPath];
        if (indexPath.section == 0) {
            [headerView setupWithText:self.content[(NSUInteger) indexPath.section][@"title"] multipleSections:NO separator:NO];
        }
        else {
            [headerView setupWithText:self.content[(NSUInteger) indexPath.section][@"title"] multipleSections:YES separator:![self.content[(NSUInteger) indexPath.section - 1][@"showAttribution"] boolValue]];
        }

        return headerView;
    } else if (kind == UICollectionElementKindSectionFooter) {
        IMCollectionReusableAttributionView *attributionView = (IMCollectionReusableAttributionView *) [self dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionFooter
                                                                                                                                withReuseIdentifier:IMCollectionReusableAttributionViewReuseId
                                                                                                                                       forIndexPath:indexPath];

        [attributionView setupWithAttribution:self.currentAttribution];
        attributionView.artistPicture.image = self.artistPicture;
        attributionView.attributionViewDelegate = self;

        return attributionView;
    }

    return nil;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section {
    if (self.currentHeader.length > 0) {
        if (section == 0) {
            return CGSizeMake(self.frame.size.width, IMCollectionReusableHeaderViewDefaultHeight);
        } else if (([self.content[(NSUInteger) section - 1][@"showAttribution"] boolValue])) {
            return CGSizeMake(self.frame.size.width, IMCollectionReusableHeaderViewDefaultHeight + 12.0f);
        }

        return CGSizeMake(self.frame.size.width, IMCollectionReusableHeaderViewDefaultHeight + 30.0f);
    }

    return CGSizeZero;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForFooterInSection:(NSInteger)section {
    if ([self.content[(NSUInteger) section][@"showAttribution"] boolValue]) {
        return CGSizeMake(self.frame.size.width, IMCollectionReusableAttributionViewDefaultHeight);
    }

    return CGSizeZero;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    self.tapGesture.enabled = NO;

    id cellContent = self.content[(NSUInteger) indexPath.section][@"imojis"][(NSUInteger) indexPath.row];

    if (cellContent == self.loadingIndicatorObject) {
        IMCollectionViewStatusCell *cell =
                (IMCollectionViewStatusCell *) [self dequeueReusableCellWithReuseIdentifier:IMCollectionViewStatusCellReuseId forIndexPath:indexPath];

        if (cellContent == self.loadingIndicatorObject) {
            [cell showLoading];
        } else {
            [cell showNoResults];
        }

        return cell;
    } else if (self.contentType == IMCollectionViewContentTypeImojiCategories) {
        IMImojiCategoryObject *categoryObject = cellContent;
        IMCategoryCollectionViewCell *cell =
                (IMCategoryCollectionViewCell *) [self dequeueReusableCellWithReuseIdentifier:IMCategoryCollectionViewCellReuseId forIndexPath:indexPath];

        // category hasn't loaded yet
        if ([cellContent isKindOfClass:[NSNull class]]) {
            [cell loadImojiCategory:@"" imojiImojiImage:nil];
        } else {
            [cell loadImojiCategory:categoryObject.title imojiImojiImage:nil];

            id image = self.images[(NSUInteger) indexPath.section][(NSUInteger) indexPath.item];
            if ([image isKindOfClass:[UIImage class]]) {
                [cell loadImojiCategory:categoryObject.title imojiImojiImage:image];
            }
        }

        return cell;
    } else if (self.contentType == IMCollectionViewContentTypeCollectionSplash) {
        IMCollectionViewSplashCell *splashCell =
                (IMCollectionViewSplashCell *) [self dequeueReusableCellWithReuseIdentifier:IMCollectionViewSplashCellReuseId forIndexPath:indexPath];

        self.tapGesture.enabled = YES;
        [self.loadingView fadeOutWithDuration:0.1 delay:0];
        [splashCell showSplashCellType:IMCollectionViewSplashCellCollection withImageBundle:self.imagesBundle];
        return splashCell;
    } else if (self.contentType == IMCollectionViewContentTypeRecentsSplash) {
        IMCollectionViewSplashCell *splashCell =
                (IMCollectionViewSplashCell *) [self dequeueReusableCellWithReuseIdentifier:IMCollectionViewSplashCellReuseId forIndexPath:indexPath];

        self.tapGesture.enabled = YES;
        [self.loadingView fadeOutWithDuration:0.1 delay:0];
        [splashCell showSplashCellType:IMCollectionViewSplashCellRecents withImageBundle:self.imagesBundle];
        return splashCell;
    } else if (self.contentType == IMCollectionViewContentTypeNoConnectionSplash) {
        IMCollectionViewSplashCell *splashCell =
                (IMCollectionViewSplashCell *) [self dequeueReusableCellWithReuseIdentifier:IMCollectionViewSplashCellReuseId forIndexPath:indexPath];

        self.tapGesture.enabled = YES;
        [self.loadingView fadeOutWithDuration:0.1 delay:0];
        [splashCell showSplashCellType:IMCollectionViewSplashCellNoConnection withImageBundle:self.imagesBundle];
        return splashCell;
    } else if (self.contentType == IMCollectionViewContentTypeNoResultsSplash) {
        IMCollectionViewSplashCell *splashCell =
                (IMCollectionViewSplashCell *) [self dequeueReusableCellWithReuseIdentifier:IMCollectionViewSplashCellReuseId forIndexPath:indexPath];

        self.tapGesture.enabled = YES;
        [self.loadingView fadeOutWithDuration:0.1 delay:0];
        [splashCell showSplashCellType:IMCollectionViewSplashCellNoResults withImageBundle:self.imagesBundle];
        return splashCell;
    } else {
        IMCollectionViewCell *cell =
                (IMCollectionViewCell *) [self dequeueReusableCellWithReuseIdentifier:IMCollectionViewCellReuseId forIndexPath:indexPath];
        [cell loadImojiImage:nil];

        id imojiImage = self.images[(NSUInteger) indexPath.section][(NSUInteger) indexPath.row];
        if ([imojiImage isKindOfClass:[UIImage class]]) {
            [cell loadImojiImage:((UIImage *) imojiImage)];
        }

        return cell;
    }
}

#pragma mark UICollectionViewDelegate

- (BOOL)collectionView:(UICollectionView *)collectionView shouldSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    id cellContent = self.content[(NSUInteger) indexPath.section][@"imojis"][(NSUInteger) indexPath.row];
    return cellContent && ![cellContent isKindOfClass:[NSNull class]];
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    id cellContent = self.content[(NSUInteger) indexPath.section][@"imojis"][(NSUInteger) indexPath.row];

    if ([cellContent isKindOfClass:[IMImojiObject class]]) {
        if ([self.collectionViewDelegate respondsToSelector:@selector(userDidSelectImoji:fromCollectionView:)]) {
            [self.collectionViewDelegate userDidSelectImoji:cellContent
                                         fromCollectionView:self];
        }

        IMCollectionViewCell *cell = (IMCollectionViewCell *) [collectionView cellForItemAtIndexPath:indexPath];
        cell.imojiView.highlighted = NO;

        if (self.animateSelection) {
            [self processCellAnimations:indexPath];
        }

    } else if ([cellContent isKindOfClass:[IMImojiCategoryObject class]]) {
        if ([self.collectionViewDelegate respondsToSelector:@selector(userDidSelectCategory:fromCollectionView:)]) {
            [self.collectionViewDelegate userDidSelectCategory:cellContent
                                            fromCollectionView:self];
        }

        IMCategoryCollectionViewCell *cell = (IMCategoryCollectionViewCell *) [collectionView cellForItemAtIndexPath:indexPath];
        cell.imojiView.highlighted = NO;
    }
}

- (void)collectionView:(UICollectionView *)collectionView willDisplayCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath {
    if ([cell isKindOfClass:[IMCollectionViewStatusCell class]]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self loadNextPageOfImojisFromSearch];
        });
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    // check to see if the user is at the end of the scrollview
    // this is a iOS 7 safe approach since collectionView:willDisplayCell:forItemAtIndexPath:indexPath
    // is not supported`
    if ([self numberOfSections] > 0 && [self.collectionViewLayout isKindOfClass:[UICollectionViewFlowLayout class]]) {
        NSUInteger loadingPosition = [self.content[(NSUInteger) self.numberOfSections - 1][@"imojis"] indexOfObject:self.loadingIndicatorObject];

        if (loadingPosition != NSNotFound) {
            UICollectionViewFlowLayout *flowLayout = (UICollectionViewFlowLayout *) self.collectionViewLayout;

            CGSize loadingCellSize = [self collectionView:self
                                                   layout:flowLayout
                                   sizeForItemAtIndexPath:[NSIndexPath indexPathForItem:loadingPosition inSection:(NSUInteger) self.numberOfSections - 1]];

            BOOL userIsAtEndOfList;
            if (flowLayout.scrollDirection == UICollectionViewScrollDirectionHorizontal) {
                userIsAtEndOfList = self.contentOffset.x + self.frame.size.width >= self.contentSize.width - loadingCellSize.width;
            } else {
                userIsAtEndOfList = self.contentOffset.y + self.frame.size.height >= self.contentSize.height - loadingCellSize.height;
            }

            if (userIsAtEndOfList && NSFoundationVersionNumber < NSFoundationVersionNumber_iOS_8_0) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self loadNextPageOfImojisFromSearch];
                });
            }
        }
    }

    if (self.collectionViewDelegate && [self.collectionViewDelegate respondsToSelector:@selector(imojiCollectionViewDidScroll:)]) {
        [self.collectionViewDelegate imojiCollectionViewDidScroll:self];
    }
}

#pragma mark UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath {

    UIEdgeInsets insets = [self collectionView:collectionView
                                        layout:collectionViewLayout
                        insetForSectionAtIndex:indexPath.section];

    CGSize availableSize = CGSizeMake(
            self.frame.size.width - insets.right - insets.left - self.contentInset.left - self.contentInset.right,
            self.frame.size.height - insets.top - insets.bottom - self.contentInset.top - self.contentInset.bottom
    );

    // splash views occupy the full screen
    switch (self.contentType) {
        case IMCollectionViewContentTypeRecentsSplash:
        case IMCollectionViewContentTypeCollectionSplash:
        case IMCollectionViewContentTypeNoConnectionSplash:
        case IMCollectionViewContentTypeEnableFullAccessSplash:
        case IMCollectionViewContentTypeNoResultsSplash: {

            return availableSize;
        }
        default: {
            if ([self isPathShowingLoadingIndicator:indexPath]) {
                if (NSFoundationVersionNumber < NSFoundationVersionNumber_iOS_8_0 && [self numberOfItemsInSection:indexPath.section] == 1) {
                    return availableSize;
                } else {
                    return CGSizeMake(availableSize.width, self.preferredImojiDisplaySize.height);
                }
            }

            // ensure the Imoji stickers take up the entire view space so that they
            // do not get aligned to the edges when not using maxium space

            CGFloat numberOfImagesPerRow = floorf(availableSize.width / self.preferredImojiDisplaySize.width);
            CGFloat paddedSpace =
                    self.preferredImojiDisplaySize.width * (
                            availableSize.width / self.preferredImojiDisplaySize.width -
                                    numberOfImagesPerRow
                    ) / numberOfImagesPerRow;

            return CGSizeMake(
                    floorf(self.preferredImojiDisplaySize.width + paddedSpace),
                    floorf(self.preferredImojiDisplaySize.height + paddedSpace)
            );
        }
    }
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView
                        layout:(UICollectionViewLayout *)collectionViewLayout
        insetForSectionAtIndex:(NSInteger)section {
    if (self.contentType == IMCollectionViewContentTypeImojiCategories) {
        return UIEdgeInsetsMake(5.0f, 5.0f, 5.0f, 5.0f);
    }

    return UIEdgeInsetsZero;
}

- (CGFloat)          collectionView:(UICollectionView *)collectionView
                             layout:(UICollectionViewLayout *)collectionViewLayout
minimumLineSpacingForSectionAtIndex:(NSInteger)section {
    if (self.contentType == IMCollectionViewContentTypeImojiCategories) {
        return 15.0f;
    }

    return 0;
}

- (CGFloat)               collectionView:(UICollectionView *)collectionView
                                  layout:(UICollectionViewLayout *)collectionViewLayout
minimumInteritemSpacingForSectionAtIndex:(NSInteger)section {
    return 0;
}

#pragma mark Supplementary View Delegates

- (void)userDidSelectAttributionLink:(NSURL *)attributionLink fromCollectionReusableView:(IMCollectionReusableAttributionView *)footerView {
    if (self.collectionViewDelegate && [self.collectionViewDelegate respondsToSelector:@selector(userDidSelectAttributionLink: fromCollectionView:)]) {
        [self.collectionViewDelegate userDidSelectAttributionLink:attributionLink fromCollectionView:self];
    }
}

#pragma mark Imoji Loading

- (void)loadImojiCategories:(IMImojiSessionCategoryClassification)classification {
    self.shouldShowAttribution = self.shouldLoadNewSection = NO;
    switch (classification) {
        case IMImojiSessionCategoryClassificationTrending:
            self.currentHeader = [IMResourceBundleUtil localizedStringForKey:@"collectionReusableHeaderViewTrending"];
            break;
        case IMImojiSessionCategoryClassificationGeneric:
            self.currentHeader = [IMResourceBundleUtil localizedStringForKey:@"collectionReusableHeaderViewReactions"];
            break;
        case IMImojiSessionCategoryClassificationArtist:
            self.currentHeader = [IMResourceBundleUtil localizedStringForKey:@"collectionReusableHeaderViewArtist"];
            break;
        default:
            break;
    }

    if (![IMConnectivityUtil sharedInstance].hasConnectivity) {
        self.contentType = IMCollectionViewContentTypeNoConnectionSplash;
        return;
    }

    self.contentType = IMCollectionViewContentTypeImojiCategories;
    [self generateNewResultSetOperationWithSearchOffset:nil];

    __block NSOperation *operation;
    self.imojiOperation = operation =
            [self.session getImojiCategoriesWithClassification:classification
                                                      callback:^(NSArray *imojiCategories, NSError *error) {
                                                          if (error) {
                                                              return;
                                                          }

                                                          [self prepareViewForImojiResultSet:@([imojiCategories count])
                                                                                      offset:0
                                                                                       error:error
                                                                     emptyResultsContentType:IMCollectionViewContentTypeNoResultsSplash];

                                                          for (IMImojiCategoryObject *category in imojiCategories) {
                                                              if (operation.isCancelled) {
                                                                  break;
                                                              }

                                                              NSUInteger index = [imojiCategories indexOfObject:category];
                                                              [self renderImojiResult:category.previewImojis ? category.previewImojis[arc4random() % category.previewImojis.count] : category.previewImoji
                                                                              content:category
                                                                            atSection:(NSUInteger) self.numberOfSections - 1
                                                                              atIndex:index
                                                                               offset:0
                                                                            operation:operation];
                                                          }

                                                          if (!operation.isCancelled && self.collectionViewDelegate && [self.collectionViewDelegate respondsToSelector:@selector(imojiCollectionView:didFinishLoadingContentType:)]) {
                                                              [self.collectionViewDelegate imojiCollectionView:self didFinishLoadingContentType:self.contentType];
                                                          }
                                                      }];
}

- (void)loadFeaturedImojis {
    self.shouldShowAttribution = self.shouldLoadNewSection = NO;
    if (![IMConnectivityUtil sharedInstance].hasConnectivity) {
        self.contentType = IMCollectionViewContentTypeNoConnectionSplash;
        return;
    }

    self.contentType = IMCollectionViewContentTypeImojis;
    [self generateNewResultSetOperationWithSearchOffset:nil];

    __block NSOperation *operation;
    self.imojiOperation = operation =
            [self.session getFeaturedImojisWithNumberOfResults:@(self.numberOfImojisToLoad)
                                     resultSetResponseCallback:^(IMImojiResultSetMetadata *metadata, NSError *error) {
                                         if (!operation.isCancelled) {
                                             [self prepareViewForImojiResultSet:metadata.resultCount
                                                                         offset:0
                                                                          error:error
                                                        emptyResultsContentType:IMCollectionViewContentTypeNoResultsSplash];
                                         }
                                     }
                                         imojiResponseCallback:^(IMImojiObject *imoji, NSUInteger index, NSError *error) {
                                             if (!operation.isCancelled && !error) {
                                                 [self renderImojiResult:imoji
                                                                 content:imoji
                                                               atSection:(NSUInteger) self.numberOfSections - 1
                                                                 atIndex:index
                                                                  offset:0
                                                               operation:operation];
                                             }
                                         }];
}

- (void)loadImojisFromSearch:(NSString *)searchTerm {
    self.shouldShowAttribution = self.shouldLoadNewSection = NO;
    self.currentHeader = searchTerm;
    [self loadImojisFromSearch:searchTerm offset:nil infiniteScrollEnabled:NO];
}

- (void)loadImojisFromSentence:(NSString *)sentence {
    self.shouldShowAttribution = self.shouldLoadNewSection = NO;
    if (![IMConnectivityUtil sharedInstance].hasConnectivity) {
        self.contentType = IMCollectionViewContentTypeNoConnectionSplash;
        return;
    }

    self.currentSearchTerm = nil;
    self.contentType = IMCollectionViewContentTypeImojis;
    [self generateNewResultSetOperationWithSearchOffset:nil];

    __block NSOperation *operation;
    self.imojiOperation = operation =
            [self.session searchImojisWithSentence:sentence
                                   numberOfResults:@(self.numberOfImojisToLoad)
                         resultSetResponseCallback:^(IMImojiResultSetMetadata *metadata, NSError *error) {
                             if (!operation.isCancelled) {
                                 [self prepareViewForImojiResultSet:metadata.resultCount
                                                             offset:0
                                                              error:error
                                            emptyResultsContentType:IMCollectionViewContentTypeNoResultsSplash];
                             }
                         }
                             imojiResponseCallback:^(IMImojiObject *imoji, NSUInteger index, NSError *error) {
                                 if (!operation.isCancelled && !error) {
                                     [self renderImojiResult:imoji
                                                     content:imoji
                                                   atSection:(NSUInteger) self.numberOfSections - 1
                                                     atIndex:index
                                                      offset:0
                                                   operation:operation];
                                 }
                             }];
}

- (void)loadImojisFromIdentifiers:(NSArray *)imojiIdentifiers {
    self.shouldShowAttribution = self.shouldLoadNewSection = NO;
    if (![IMConnectivityUtil sharedInstance].hasConnectivity) {
        self.contentType = IMCollectionViewContentTypeNoConnectionSplash;
        return;
    }

    self.contentType = IMCollectionViewContentTypeImojis;
    [self generateNewResultSetOperationWithSearchOffset:nil];

    // allow the loading indicator to display by calling generateNewResultSetOperationWithSearchOffset:
    // before we reload the views
    dispatch_async(dispatch_get_main_queue(), ^{
        [self prepareViewForImojiResultSet:@(imojiIdentifiers.count)
                                    offset:0
                                     error:nil
                   emptyResultsContentType:IMCollectionViewContentTypeNoResultsSplash];

        __block NSOperation *operation;
        self.imojiOperation = operation =
                [self.session fetchImojisByIdentifiers:imojiIdentifiers
                               fetchedResponseCallback:^(IMImojiObject *imoji, NSUInteger index, NSError *error) {
                                   if (!operation.isCancelled && !error) {
                                       [self renderImojiResult:imoji
                                                       content:imoji
                                                     atSection:(NSUInteger) self.numberOfSections - 1
                                                       atIndex:index
                                                        offset:0
                                                     operation:operation];
                                   }
                               }];
    });
}

- (void)loadUserCollectionImojis {
    self.shouldShowAttribution = self.shouldLoadNewSection = NO;
    if (![IMConnectivityUtil sharedInstance].hasConnectivity) {
        self.contentType = IMCollectionViewContentTypeNoConnectionSplash;
        return;
    }

    self.contentType = IMCollectionViewContentTypeImojis;
    [self generateNewResultSetOperationWithSearchOffset:nil];

    __block NSOperation *operation;
    self.imojiOperation = operation =
            [self.session getImojisForAuthenticatedUserWithResultSetResponseCallback:^(IMImojiResultSetMetadata *metadata, NSError *error) {
                        if (!operation.isCancelled) {
                            [self prepareViewForImojiResultSet:metadata.resultCount
                                                        offset:0
                                                         error:error
                                       emptyResultsContentType:IMCollectionViewContentTypeCollectionSplash];
                        }
                    }
                                                               imojiResponseCallback:^(IMImojiObject *imoji, NSUInteger index, NSError *error) {
                                                                   if (!operation.isCancelled && !error) {
                                                                       [self renderImojiResult:imoji
                                                                                       content:imoji
                                                                                     atSection:(NSUInteger) self.numberOfSections - 1
                                                                                       atIndex:index
                                                                                        offset:0
                                                                                     operation:operation];
                                                                   }
                                                               }];
}

- (void)loadImojisFromCategory:(nonnull IMImojiCategoryObject *)category {
    self.shouldShowAttribution = self.shouldLoadNewSection = NO;
    self.currentHeader = category.title;

    if (category.attribution) {
        self.shouldShowAttribution = YES;

        [self.session renderImoji:category.attribution.artist.previewImoji
                          options:self.renderingOptions
                         callback:^(UIImage *image, NSError *renderError) {
                             if (renderError == nil) {
                                 self.artistPicture = image;
                             }
                         }];

        self.currentAttribution = category.attribution;
    }

    [self loadImojisFromSearch:category.identifier offset:nil infiniteScrollEnabled:YES];
}

- (void)displaySplashOfType:(IMCollectionViewSplashCellType)splashType {
    self.shouldShowAttribution = self.shouldLoadNewSection = NO;
    switch (splashType) {
        case IMCollectionViewSplashCellNoConnection:
            self.contentType = IMCollectionViewContentTypeNoConnectionSplash;
            break;

        case IMCollectionViewSplashCellEnableFullAccess:
            self.contentType = IMCollectionViewContentTypeEnableFullAccessSplash;
            break;

        case IMCollectionViewSplashCellNoResults:
            self.contentType = IMCollectionViewContentTypeNoResultsSplash;
            break;

        case IMCollectionViewSplashCellRecents:
            self.contentType = IMCollectionViewContentTypeRecentsSplash;
            break;

        case IMCollectionViewSplashCellCollection:
            self.contentType = IMCollectionViewContentTypeCollectionSplash;
            break;

        default:
            break;
    }
}

#pragma mark Private Imoji Loading Methods

- (void)loadImojisFromSearch:(NSString *)searchTerm offset:(NSNumber *)offset infiniteScrollEnabled:(BOOL)infiniteScrollEnabled {
    if (![IMConnectivityUtil sharedInstance].hasConnectivity) {
        self.contentType = IMCollectionViewContentTypeNoConnectionSplash;
        return;
    }

    NSUInteger offsetValue = offset ? offset.unsignedIntegerValue - 1 : 0;

    if (!offset) {
        self.contentType = IMCollectionViewContentTypeImojis;
        [self generateNewResultSetOperationWithSearchOffset:offset];
    }

    self.currentSearchTerm = searchTerm;

    self.shouldLoadNewSection = NO;
    __block NSOperation *operation;
    __block NSUInteger currentSection = (NSUInteger) self.numberOfSections - 1;
    self.imojiOperation = operation =
            [self.session searchImojisWithTerm:searchTerm
                                        offset:offset
                               numberOfResults:@(self.numberOfImojisToLoad)
                     resultSetResponseCallback:^(IMImojiResultSetMetadata *metadata, NSError *error) {
                         if (!operation.isCancelled) {
                             NSNumber *resultCount = metadata.resultCount;
                             // if the resultCount is 0 then followUpSearchTerm returns nil
                             // avoid that case by setting the followUpSearchTerm whenever resultCount is above 0
                             if (self.infiniteScroll
                                     && infiniteScrollEnabled
                                     && resultCount.unsignedIntegerValue > 0) {
                                 self.followUpSearchTerm = metadata.relatedSearchTerm;
                             }

                             [self prepareViewForImojiResultSet:resultCount
                                                         offset:offsetValue
                                                          error:error
                                        emptyResultsContentType:IMCollectionViewContentTypeNoResultsSplash];

                             // Prepare to load new section
                             if (self.infiniteScroll
                                     && infiniteScrollEnabled
                                     && resultCount.unsignedIntegerValue < self.numberOfImojisToLoad
                                     && self.contentType != IMCollectionViewContentTypeNoResultsSplash) {
                                 // Checks for when the followUpSearchTerm is the same as the searchTerm (current)
                                 // and the resultCount is 0. This means the search with the followUpSearchTerm returned no results.
                                 if (self.followUpSearchTerm != searchTerm) {
                                     self.currentSearchTerm = self.followUpSearchTerm;
                                     self.shouldLoadNewSection = YES;

                                     // Only append a loading indicator to the next section when resultCount is 0
                                     // Otherwise, proceed to next callback
                                     if (resultCount.unsignedIntegerValue == 0) {
                                         self.currentHeader = self.currentSearchTerm;
                                         self.shouldShowAttribution = NO;
                                         dispatch_async(dispatch_get_main_queue(), ^{
                                             [self prepareViewForNextSection];
                                         });
                                     }
                                 }
                             }
                         }
                     } imojiResponseCallback:^(IMImojiObject *imoji, NSUInteger index, NSError *error) {
                        if (!operation.isCancelled && !error) {
                            [self renderImojiResult:imoji
                                            content:imoji
                                          atSection:currentSection
                                            atIndex:index
                                             offset:offsetValue
                                          operation:operation];
                        }

                        // append the loading indicator to the content to fetch the next set of results
                        if (index + 1 == self.numberOfImojisToLoad) {
                            [self performBatchUpdates:^{
                                [self.content[currentSection][@"imojis"] addObject:self.loadingIndicatorObject];
                                [self insertItemsAtIndexPaths:@[
                                        [NSIndexPath indexPathForItem:[self numberOfItemsInSection:currentSection] - 1
                                                            inSection:currentSection]
                                ]];
                            }              completion:nil];
                        } else if (self.infiniteScroll && infiniteScrollEnabled && self.shouldLoadNewSection &&
                                index + 1 == [self numberOfItemsInSection:currentSection] % self.numberOfImojisToLoad) {
                            // append the loading indicator to the next section if
                            // a new section should be loaded.
                            // and the index + 1 is equal to the number of items to be
                            //   loaded in a section (modulo the numberOfImojisToLoad)
                            self.currentHeader = self.currentSearchTerm;
                            self.shouldShowAttribution = NO;
                            [self prepareViewForNextSection];
                        }
                    }];
}

- (void)loadNextPageOfImojisFromSearch {
    // do not append the next set of imojis until the current set of them has completely rendered to avoid
    // mutating the data model while the collection view is reloading
    if (self.currentSearchTerm != nil) {
        __block NSMutableArray *imojis = self.content[(NSUInteger) self.numberOfSections - 1][@"imojis"];
        if (![imojis containsObject:self.loadingIndicatorObject]) {
            return;
        }

        [self performBatchUpdates:^{
            [imojis removeObject:self.loadingIndicatorObject];

            // Remove the first item in the indexPaths when there are no items in the content array
            if ([self numberOfItemsInSection:self.numberOfSections - 1] == 0) {
                [self deleteItemsAtIndexPaths:@[[NSIndexPath indexPathForItem:0 inSection:(NSUInteger) self.numberOfSections - 1]]];
            } else {
                [self deleteItemsAtIndexPaths:@[[NSIndexPath indexPathForItem:[self numberOfItemsInSection:self.numberOfSections - 1] inSection:(NSUInteger) self.numberOfSections - 1]]];
            }
        }              completion:^(BOOL finished) {
            [self loadImojisFromSearch:self.currentSearchTerm offset:@([self numberOfItemsInSection:self.numberOfSections - 1] + 1) infiniteScrollEnabled:YES];
        }];
    }
}

- (void)prepareViewForNextSection {
    [self performBatchUpdates:^{
        [self.content addObject:@{
                @"title" : self.currentHeader,
                @"imojis" : [@[self.loadingIndicatorObject] mutableCopy],
                @"showAttribution" : @(self.shouldShowAttribution)
        }];

        [self.images addObject:[@[] mutableCopy]];
        [self insertItemsAtIndexPaths:@[
                [NSIndexPath indexPathForItem:0
                                    inSection:(NSUInteger) self.numberOfSections - 1]
        ]];
        [self insertSections:[NSIndexSet indexSetWithIndex:(NSUInteger) self.numberOfSections - 1]];
    } completion:nil];
}

- (void)generateNewResultSetOperationWithSearchOffset:(NSNumber *)searchOffset {
    if (!searchOffset && !self.shouldLoadNewSection) {
        [self.images removeAllObjects];
        [self.content removeAllObjects];
        [self.pendingCollectionViewUpdates removeAllObjects];
        self.currentSearchTerm = nil;

        self.contentOffset = CGPointMake(-self.contentInset.left, -self.contentInset.top);

        // loading indicator exists already for results with an offset
        if (self.contentType == IMCollectionViewContentTypeImojis || self.contentType == IMCollectionViewContentTypeImojiCategories) {
            [self.loadingView fadeInWithDuration:0 delay:0];

            [self.content addObject:@{
                    @"title" : self.currentHeader,
                    @"imojis" : self.numberOfSections == 0 ? [@[] mutableCopy] : [@[self.loadingIndicatorObject] mutableCopy],
                    @"showAttribution" : @(self.shouldShowAttribution)
            }];
        }
    }

    if (self.imojiOperation && !self.imojiOperation.isCancelled) {
        [self.imojiOperation cancel];
    }

    [self reloadData];
}

- (void)prepareViewForImojiResultSet:(NSNumber *)resultCount
                              offset:(NSUInteger)offset
                               error:(NSError *)error
             emptyResultsContentType:(IMCollectionViewContentType)emptyResultsContentType {
    __block NSUInteger loadingOffset = [self.content[(NSUInteger) self.numberOfSections - 1][@"imojis"] indexOfObject:self.loadingIndicatorObject];

    if (offset == 0 && self.numberOfSections < 2) {
        [self.content removeAllObjects];
        [self.images removeAllObjects];
        [self.pendingCollectionViewUpdates removeAllObjects];

        self.contentOffset = CGPointMake(-self.contentInset.left, -self.contentInset.top);

        if (resultCount.unsignedIntegerValue == 0) {
            self.contentType = emptyResultsContentType;
            return;
        }
    }

    if (!error) {
        __block NSMutableArray *insertedPaths = [NSMutableArray arrayWithCapacity:MAX(resultCount.unsignedIntegerValue, 1)];
        if (resultCount.unsignedIntegerValue > 0) {
            if (self.numberOfSections > 0) {
                [self.content[(NSUInteger) self.numberOfSections - 1][@"imojis"] removeObject:self.loadingIndicatorObject];
            } else {
                [self.content removeObject:self.loadingIndicatorObject];
            }

            for (NSUInteger i = 0; i < resultCount.unsignedIntValue; ++i) {
                if (self.numberOfSections > 0) {
                    [self.content[(NSUInteger) self.numberOfSections - 1][@"imojis"] addObject:[NSNull null]];
                    [self.images[(NSUInteger) self.numberOfSections - 1] addObject:[NSNull null]];
                } else {
                    [self.content addObject:@{
                            @"title" : self.currentHeader,
                            @"imojis" : [@[[NSNull null]] mutableCopy],
                            @"showAttribution" : @(self.shouldShowAttribution)}
                    ];
                    [self.images addObject:[@[[NSNull null]] mutableCopy]];
                }

                [insertedPaths addObject:[NSIndexPath indexPathForRow:i + offset inSection:self.numberOfSections - 1]];
            }
        }

        if (insertedPaths.count > 0 || loadingOffset != NSNotFound) {
            // TODO: address assertion issue with insert/removal that occurs when a user quickly switches from categories to imojis
            if (offset == 0) {
                [self reloadData];
            } else {
                [self performBatchUpdates:^{
                    if (loadingOffset != NSNotFound) {
                        [self deleteItemsAtIndexPaths:@[[NSIndexPath indexPathForRow:loadingOffset inSection:self.numberOfSections - 1]]];
                    }

                    if (insertedPaths.count > 0) {
                        [self insertItemsAtIndexPaths:insertedPaths];
                    }
                } completion:nil];
            }
        }

        [self.loadingView fadeOutWithDuration:0.2 delay:0];

        if (self.collectionViewDelegate && [self.collectionViewDelegate respondsToSelector:@selector(imojiCollectionView:didFinishLoadingContentType:)]) {
            [self.collectionViewDelegate imojiCollectionView:self didFinishLoadingContentType:self.contentType];
        }
    }
}

- (void)renderImojiResult:(IMImojiObject *)imoji
                  content:(id)content
                atSection:(NSUInteger)section
                  atIndex:(NSUInteger)index
                   offset:(NSUInteger)offset
                operation:(NSOperation *)operation {
    self.content[section][@"imojis"][index + offset] = content;
    [self.session renderImoji:imoji
                      options:self.renderingOptions
                     callback:^(UIImage *image, NSError *renderError) {
                         if (!operation.isCancelled && [self.images[section] count] > index + offset) {
                             NSIndexPath *newPath = [NSIndexPath indexPathForItem:(index + offset) inSection:section];
                             self.images[section][index + offset] = image ? image : [NSNull null];

                             BOOL doReload = self.pendingCollectionViewUpdates.count == 0;
                             [self.pendingCollectionViewUpdates addObject:newPath];

                             // immediately reload cells for iOS 8 and later, for iOS 7, we need to batch the updates
                             if (NSFoundationVersionNumber < NSFoundationVersionNumber_iOS_8_0) {
                                 BOOL doReload = self.pendingCollectionViewUpdates.count == 0;
                                 [self.pendingCollectionViewUpdates addObject:newPath];
                                 
                                 // if the pending collection view list was empty, go ahead and call the reload method, otherwise, allow
                                 // the method to perform the reload after the last batch update completes
                                 
                                 if (doReload) {
                                     [self reloadPendingUpdatesWithOperation:operation];
                                 }
                             } else {
                                 // Dubsmash's hacky way of doing things so that they kinda work
                                 UICollectionViewCell *cell = [self cellForItemAtIndexPath:newPath];
                                 if ([cell isKindOfClass:[IMCategoryCollectionViewCell class]]) {
                                     id cellContent = self.content[(NSUInteger) newPath.section][@"imojis"][(NSUInteger) newPath.row];
                                     if (![cellContent isKindOfClass:[NSNull class]]) {
                                         id image = self.images[(NSUInteger) newPath.section][(NSUInteger) newPath.item];
                                         if ([image isKindOfClass:[UIImage class]]) {
                                             [(IMCategoryCollectionViewCell *)cell loadImojiCategory:((IMImojiCategoryObject *)cellContent).title imojiImojiImage:image];
                                         }
                                     }
                                 } else if ([cell isKindOfClass:[IMCollectionViewCell class]]) {
                                     id image = self.images[(NSUInteger) newPath.section][(NSUInteger) newPath.item];
                                     if ([image isKindOfClass:[UIImage class]]) {
                                         [(IMCollectionViewCell *)cell loadImojiImage:image];
                                     }
                                 }
                             }
                         }
                     }];
}

- (void)reloadPendingUpdatesWithOperation:(NSOperation *)operation {
    if (self.pendingCollectionViewUpdates.count > 0) {
        __block NSOrderedSet *updates = [NSOrderedSet orderedSetWithArray:self.pendingCollectionViewUpdates];
        [self performBatchUpdates:^{
            if (!operation.isCancelled) {
                [self reloadItemsAtIndexPaths:updates.array];
            }
        } completion:^(BOOL finished) {
            [self.pendingCollectionViewUpdates removeObjectsInArray:updates.array];
            // recurse in case there are new items to reload
            [self reloadPendingUpdatesWithOperation:operation];
        }];
    }
}

- (void)userTappedSplashView:(UITapGestureRecognizer *)sender {
    if (self.collectionViewDelegate && [self.collectionViewDelegate respondsToSelector:@selector(userDidSelectSplash:fromCollectionView:)]) {
        switch (self.contentType) {
            case IMCollectionViewContentTypeRecentsSplash:
                [self.collectionViewDelegate userDidSelectSplash:IMCollectionViewSplashCellRecents fromCollectionView:self];
                break;

            case IMCollectionViewContentTypeCollectionSplash:
                [self.collectionViewDelegate userDidSelectSplash:IMCollectionViewSplashCellCollection fromCollectionView:self];
                break;

            case IMCollectionViewContentTypeNoConnectionSplash:
                [self.collectionViewDelegate userDidSelectSplash:IMCollectionViewSplashCellNoConnection fromCollectionView:self];
                break;

            case IMCollectionViewContentTypeEnableFullAccessSplash:
                [self.collectionViewDelegate userDidSelectSplash:IMCollectionViewSplashCellEnableFullAccess fromCollectionView:self];
                break;

            case IMCollectionViewContentTypeNoResultsSplash:
                [self.collectionViewDelegate userDidSelectSplash:IMCollectionViewSplashCellNoResults fromCollectionView:self];
                break;

            default:
                break;
        }
    }
}

#pragma mark Public Overridable Methods

- (void)processCellAnimations:(NSIndexPath *)currentIndexPath {
    for (UICollectionViewCell *cell in self.visibleCells) {
        NSIndexPath *indexPath = [self indexPathForCell:cell];

        if ([cell respondsToSelector:@selector(performGrowAnimation)] &&
                [cell respondsToSelector:@selector(performTranslucentAnimation)]) {
            if (currentIndexPath.row == indexPath.row) {
                [(IMCollectionViewCell *) cell performGrowAnimation];
            } else {
                [(IMCollectionViewCell *) cell performTranslucentAnimation];
            }
        }
    }
}

- (id)contentForIndexPath:(NSIndexPath *)path {
    return path.row > [self numberOfItemsInSection:path.section] ? nil : self.content[(NSUInteger) path.section][@"imojis"][(NSUInteger) path.row];
}

- (BOOL)isPathShowingLoadingIndicator:(NSIndexPath *)indexPath {
    id cellContent = [self contentForIndexPath:indexPath];
    return (cellContent == self.loadingIndicatorObject);
}

#pragma mark Properties

- (void)setNumberOfImojisToLoad:(NSUInteger)numberOfImojisToLoad {
    _numberOfImojisToLoad = numberOfImojisToLoad;
    [self reloadData];
}

- (void)setPreferredImojiDisplaySize:(CGSize)preferredImojiDisplaySize {
    _preferredImojiDisplaySize = preferredImojiDisplaySize;
    [self reloadData];
}

- (void)setRenderingOptions:(IMImojiObjectRenderingOptions *)renderingOptions {
    _renderingOptions = renderingOptions;
    [self reloadData];
}

- (void)setImagesBundle:(NSBundle *)imagesBundle {
    _imagesBundle = imagesBundle;
    [self reloadData];
}

- (void)setContentType:(IMCollectionViewContentType)contentType {
    BOOL dirty = _contentType != contentType;
    _contentType = contentType;

    if (dirty) {
        switch (contentType) {
            case IMCollectionViewContentTypeRecentsSplash:
            case IMCollectionViewContentTypeCollectionSplash:
            case IMCollectionViewContentTypeNoConnectionSplash:
            case IMCollectionViewContentTypeEnableFullAccessSplash:
            case IMCollectionViewContentTypeNoResultsSplash:

                // add a filler object for rendering splashes
                [self.content removeAllObjects];
                [self.content addObject:@{
                        @"title" : self.currentHeader,
                        @"imojis" : [@[[NSNull null]] mutableCopy],
                        @"showAttribution" : @(self.shouldShowAttribution)
                }];
                break;

            default:
                break;
        }

        [self reloadData];
    }
}

#pragma mark Initialization

+ (instancetype)imojiCollectionViewWithSession:(IMImojiSession *)session {
    return [[IMCollectionView alloc] initWithSession:session];
}

@end
