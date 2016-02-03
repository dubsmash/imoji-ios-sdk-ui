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

#import <Masonry/Masonry.h>
#import "IMCollectionViewController.h"
#import "IMResourceBundleUtil.h"

CGFloat const IMCollectionViewControllerBottomBarDefaultHeight = 60.0f;
UIEdgeInsets const IMCollectionViewControllerSearchFieldInsets = {0, 10, 0, 10};
UIEdgeInsets const IMCollectionViewControllerBackButtonInsets = {0, 10, 0, 10};
NSUInteger const IMCollectionViewControllerDefaultSearchDelayInMillis = 150;

@interface IMCollectionViewController () <UISearchBarDelegate, IMToolbarDelegate>

@property(nonatomic, strong) NSOperation *pendingSearchOperation;
@end

@implementation IMCollectionViewController {

}

- (instancetype)initWithSession:(IMImojiSession *)session {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        [self setupCollectionViewControllerWithSession:session];
    }

    return self;
}

- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        [self setupCollectionViewControllerWithSession:[IMImojiSession imojiSession]];
    }

    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        [self setupCollectionViewControllerWithSession:[IMImojiSession imojiSession]];
    }

    return self;
}

- (void)setupCollectionViewControllerWithSession:(IMImojiSession *)session {
    self.session = session;

    _bottomToolbar = [IMToolbar new];
    _topToolbar = [IMToolbar new];
    _collectionView = [self createCollectionViewWithSession:session];
    _searchOnTextChanges = YES;
    _autoSearchDelayTimeInMillis = IMCollectionViewControllerDefaultSearchDelayInMillis;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardDisplayedForSearchField:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHideForSearchField:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];

    _backButton = (UIButton *) [self.topToolbar addToolbarButtonWithType:IMToolbarButtonBack].customView;
    _searchField = (UISearchBar *) [self.topToolbar addSearchBarItem].customView;
    _searchField.delegate = self;
    if ([_searchField respondsToSelector:@selector(setEnablesReturnKeyAutomatically:)]) {
        _searchField.enablesReturnKeyAutomatically = NO;
        _searchField.spellCheckingType = UITextSpellCheckingTypeNo;
    }
    _bottomToolbar.delegate = _topToolbar.delegate = self;

    self.backButton.hidden = YES;

    if (self.collectionViewControllerDelegate) {
        _collectionView.collectionViewDelegate = self.collectionViewControllerDelegate;
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)loadView {

    self.view = [UIView new];

    [self.view addSubview:self.collectionView];
    [self.view addSubview:self.topToolbar];
    [self.view addSubview:self.bottomToolbar];

    [self updateViewConstraints];

    [self setupControllerComponentsLookAndFeel];
}

- (void)setupControllerComponentsLookAndFeel {
    self.collectionView.backgroundColor = [UIColor colorWithWhite:248 / 255.0f alpha:1.0f];

    NSMutableParagraphStyle *paragraphStyle = [NSMutableParagraphStyle new];
    paragraphStyle.alignment = NSTextAlignmentLeft;

    if ([self.searchField respondsToSelector:@selector(setReturnKeyType:)]) {
        self.searchField.returnKeyType = self.searchOnTextChanges ? UIReturnKeyDone : UIReturnKeySearch;
    }
    self.searchField.placeholder = [IMResourceBundleUtil localizedStringForKey:@"collectionViewControllerSearchStickers"];

    if ([self.collectionViewControllerDelegate respondsToSelector:@selector(backgroundColorForCollectionViewController:)]) {
        self.view.backgroundColor = [self.collectionViewControllerDelegate backgroundColorForCollectionViewController:self];
    }
}

- (void)updateViewConstraints {
    [super updateViewConstraints];

    [self.collectionView mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.width.equalTo(self.view);
        make.top.equalTo(self.mas_topLayoutGuideBottom);
        make.left.equalTo(self.view);
        make.bottom.equalTo(self.view);
    }];

    [self.topToolbar mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.width.equalTo(self.view);
        make.height.equalTo(@(IMCollectionViewControllerBottomBarDefaultHeight));
        make.centerX.equalTo(self.view);
        make.top.equalTo(self.mas_topLayoutGuideBottom);
    }];

    [self.bottomToolbar mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.height.equalTo(@(IMCollectionViewControllerBottomBarDefaultHeight));
        make.left.right.and.bottom.equalTo(self.view);
    }];

    [self.searchField mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.height.and.top.equalTo(self.backButton);
        make.right.equalTo(self.view).offset(-IMCollectionViewControllerSearchFieldInsets.right);

        if (self.backButton.hidden) {
            make.left.equalTo(self.view).offset(IMCollectionViewControllerSearchFieldInsets.left);
        } else {
            make.left.equalTo(self.backButton.mas_right).offset(IMCollectionViewControllerSearchFieldInsets.left);
        }
    }];

    [self.backButton mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(self.topToolbar);
        make.left.equalTo(self.topToolbar).offset(IMCollectionViewControllerBackButtonInsets.left);
    }];

    self.bottomToolbar.hidden = !self.bottomToolbar.items || self.bottomToolbar.items.count == 0;

    // hide the top toolbar if both of the default components are hidden
    self.topToolbar.hidden = !self.topToolbar.items || self.topToolbar.items.count == 0 ||
            (self.backButton.hidden && self.searchField.hidden && self.topToolbar.items.count == 2);

    self.collectionView.scrollIndicatorInsets = self.collectionView.contentInset = UIEdgeInsetsMake(
            (!self.topToolbar.hidden ? IMCollectionViewControllerBottomBarDefaultHeight : 0),
            0,
            (!self.bottomToolbar.hidden ? IMCollectionViewControllerBottomBarDefaultHeight : 0),
            0
    );
}

#pragma mark Notifications

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    [self.collectionView.collectionViewLayout invalidateLayout];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id <UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [self.collectionView.collectionViewLayout invalidateLayout];
}

- (void)keyboardDisplayedForSearchField:(NSNotification *)notification {
    NSDictionary *keyboardInfo = [notification userInfo];
    CGRect endRect = [[keyboardInfo valueForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];

    // adjust the content size for the keyboard using the displaced height
    self.collectionView.scrollIndicatorInsets = self.collectionView.contentInset = UIEdgeInsetsMake(
            self.collectionView.contentInset.top,
            self.collectionView.contentInset.left,
            endRect.size.height,
            self.collectionView.contentInset.right
    );
}

- (void)keyboardWillHideForSearchField:(NSNotification *)notification {
    self.collectionView.scrollIndicatorInsets = self.collectionView.contentInset = UIEdgeInsetsMake(
            self.collectionView.contentInset.top,
            self.collectionView.contentInset.left,
            self.bottomToolbar.hidden ? 0 : self.bottomToolbar.frame.size.height,
            self.collectionView.contentInset.right
    );
}

#pragma mark Overrides

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (void)setSearchOnTextChanges:(BOOL)searchOnTextChanges {
    _searchOnTextChanges = searchOnTextChanges;
    if ([self.searchField respondsToSelector:@selector(setReturnKeyType:)]) {
        self.searchField.returnKeyType = searchOnTextChanges ? UIReturnKeyDone : UIReturnKeySearch;
    }
}

- (void)setCollectionViewControllerDelegate:(id)collectionViewControllerDelegate {
    _collectionViewControllerDelegate = collectionViewControllerDelegate;
    _collectionView.collectionViewDelegate = collectionViewControllerDelegate;
}

#pragma mark Search field delegates

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if (self.searchOnTextChanges) {
        if (self.pendingSearchOperation && !self.pendingSearchOperation.isCancelled) {
            [self.pendingSearchOperation cancel];
        }

        __block NSOperation *pendingSearchOperation = [NSOperation new];
        self.pendingSearchOperation = pendingSearchOperation;

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_MSEC * self.autoSearchDelayTimeInMillis), dispatch_get_main_queue(), ^{
            if (!pendingSearchOperation.isCancelled) {
                [self performSearch];
            }
        });
    }
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    if (!self.searchOnTextChanges) {
        [self performSearch];
    }

    [self.searchField resignFirstResponder];
}

- (void)performSearch {
    if (self.sentenceParseEnabled) {
        [self.collectionView loadImojisFromSentence:self.searchField.text];
    } else {
        [self.collectionView loadImojisFromSearch:self.searchField.text];
    }
}

- (void)userDidSelectToolbarButton:(IMToolbarButtonType)buttonType {
    if (self.collectionViewControllerDelegate && [self.collectionViewControllerDelegate respondsToSelector:@selector(userDidSelectToolbarButton:)]) {
        [self.collectionViewControllerDelegate userDidSelectToolbarButton:buttonType];
    }
}

- (UIBarPosition)positionForBar:(id <UIBarPositioning>)bar {
    if (![self conformsToProtocol:@protocol(IMCollectionViewControllerDelegate)] &&
            self.collectionViewControllerDelegate &&
            [self.collectionViewControllerDelegate respondsToSelector:@selector(positionForBar:)]) {
        return [self.collectionViewControllerDelegate positionForBar:bar];
    }

    return self.topToolbar == bar ?
            UIBarPositionTopAttached :
            self.bottomToolbar == bar ? UIBarPositionBottom : UIBarPositionAny;
}

#pragma mark Overridable Methods

- (nonnull IMCollectionView *)createCollectionViewWithSession:(IMImojiSession *)session {
    return [IMCollectionView imojiCollectionViewWithSession:session];
}

#pragma mark Initializers

+ (instancetype)collectionViewControllerWithSession:(IMImojiSession *)session {
    return [[IMCollectionViewController alloc] initWithSession:session];
}

@end
