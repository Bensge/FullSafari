#import <substrate.h>
#import <version.h>
#import "Private.h"

BOOL fakeHorizontalSizeClass = NO;
BOOL fakeUserInterfaceIdiom = NO;
BOOL stopNarrowLayout = NO;
BOOL dontUseNarrowLayout = NO;

%hook UIDevice

- (UIUserInterfaceIdiom)userInterfaceIdiom {
    return fakeUserInterfaceIdiom ? UIUserInterfaceIdiomPad : %orig;
}

%end

%hook UITraitCollection

- (UIUserInterfaceSizeClass)horizontalSizeClass {
    return fakeHorizontalSizeClass ? UIUserInterfaceSizeClassRegular : %orig;
}

%end

%hook NSUserDefaults

- (BOOL)boolForKey: (NSString *)key {
    return [key isEqualToString:@"ShowTabBar"] ? YES : %orig;
}

%end

@interface TabController : NSObject
@property(readonly, retain, nonatomic) TabBar *tabBar; // @synthesize tabBar=_tabBar;
@end

%hook TabController

- (BOOL)canAddNewTab {
    return YES;
}

%group iOS11
- (BOOL)canAddNewTabForPrivateBrowsing:(_Bool)arg1 {
  return YES;
}

- (BOOL)canAddNewTabForCurrentBrowsingMode {
  return YES;
}

-(void)setUsesTabBar:(_Bool)arg1 {
  arg1 = YES;
  %orig;
}
%end

%end


@interface BrowserController : UIResponder
@property(readonly, nonatomic) TabController *tabController; // @synthesize tabController=_tabController;
@end
%hook BrowserController

- (BOOL)_shouldShowTabBar {
    return YES;
}

- (CGFloat)_navigationBarOverlapHeight {
    fakeUserInterfaceIdiom = YES;
    CGFloat orig = %orig;
    fakeUserInterfaceIdiom = NO;
    return orig;
}

- (void)updateUsesTabBar {
  //explanation: if you are gonna log the whole stacktrace of the universe, you will notice that at some point,
  //apple decides in this function (or right in the previous call) whether to leave the tab bar or not based on whatever reasons they see fit
  //(aka is ipad or not or whatever). After they do all their calculations and reach a decision,
  //they do not nil the tab or touch it, but they simply do removeFromSuperview...
  //which is absolutely lovely because we can bypass that and everything's intact,
  //untouched and kept natural
  if (self.tabController.tabBar.superview && kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_11_0) {
  }
  else {
    fakeHorizontalSizeClass = YES;
    %orig;
    fakeHorizontalSizeClass = NO;
  }
}

//This is iOS 11 as well and needed but it shouldn't need grouping, I very much doubt it even exists in lower versions
- (BOOL)_isScreenBigEnoughForTabBar {
  %orig;
  return YES;
}

%group preiOS10
- (BOOL)usesNarrowLayout {
    return stopNarrowLayout ? NO : %orig;
}

- (void)_updateUsesNarrowLayout {
    stopNarrowLayout = YES;
    fakeUserInterfaceIdiom = YES;
    %orig;
    stopNarrowLayout = NO;
    fakeUserInterfaceIdiom = NO;
}

- (void)updateShowingTabBarAnimated:(BOOL)arg1 {
    fakeHorizontalSizeClass = YES;
    %orig;
    fakeHorizontalSizeClass = NO;
}

%end

%end

%hook BrowserToolbar

// Force-add the "add tab" button to the toolbar
- (NSMutableArray *)defaultItems {
    NSMutableArray *orig = %orig;
    GestureRecognizingBarButtonItem *addTabItem = MSHookIvar<GestureRecognizingBarButtonItem *>(self, "_addTabItem");

    if (!addTabItem || ![orig containsObject:addTabItem]) {
        if (!addTabItem) {
            // Recreate the "add tab" button for iOS versions that don't do that by default on iPhone models
            addTabItem = [[NSClassFromString(@"GestureRecognizingBarButtonItem") alloc] initWithImage:[[UIImage imageNamed:@"AddTab"] retain] style:0 target:[self valueForKey:@"_browserDelegate"] action:@selector(addTabFromButtonBar)];
            UILongPressGestureRecognizer *recognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(_addTabLongPressRecognized:)];
            recognizer.allowableMovement = 3.0;
            addTabItem.gestureRecognizer = recognizer;
        }
        //iOS 11 doubles the + button because of this and the thing below
        //Also, SafariPlus ditches your "+" button on iOS 11 - perhaps of this bypass, perhaps not; todo: make it SafariPlus compatible, sometime later on perhaps
        if (kCFCoreFoundationVersionNumber < kCFCoreFoundationVersionNumber_iOS_11_0) {
          [orig addObject:addTabItem];
        }
        id space = [orig objectAtIndex:2];

        NSMutableDictionary *defaultItemsForToolbarSize = [self valueForKey:@"_defaultItemsForToolbarSize"];
        if (defaultItemsForToolbarSize) {
            [self setValue:addTabItem forKey:@"_addTabItem"];
            if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_11_0) {
              [MSHookIvar<NSMutableDictionary *>(self, "_defaultItemsForToolbarSize")[@([self toolbarSize])] addObject:space];
            }
            [MSHookIvar<NSMutableDictionary *>(self, "_defaultItemsForToolbarSize")[@([self toolbarSize])] addObject:[self valueForKey:@"_addTabItem"]];
        }
    }
    return orig;
}

- (void)setItems:(NSArray *)items animated:(BOOL)arg2 {
    if ([self respondsToSelector:@selector(toolbarSize)] && [self toolbarSize] == 0) {
        NSMutableArray *newItems = [items mutableCopy];
        // Replace fixed spacers with flexible ones
        for (UIBarButtonItem *item in [newItems.copy autorelease]) {
            if ([item isSystemItem] && [item systemItem] == UIBarButtonSystemItemFixedSpace && [item width] > 0.1) {
                NSUInteger indexOfItem = [items indexOfObject:item];
                if (indexOfItem != NSNotFound)
                    [newItems replaceObjectAtIndex:indexOfItem withObject:[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil] autorelease]];
            }
        }
        items = [newItems copy];
        [newItems release];
    }
    %orig(items, arg2);
}

%end

%hook TabController

- (UIView *)tiltedTabView: (UIView *)arg1 borrowContentViewForItem: (id)arg2 withTopBackdropView: (id *)arg3 ofHeight: (CGFloat)height {
    height += [objc_getClass("TabBar") defaultHeight];
    return %orig;
}

%end

///TODO For the crazy people out there who enjoy counting rice with box gloves, here's another task: Eclipse compatibility
//FYI Fr0st is hooking UIColor and overwriting anything close to whiteColor to be the opposite

// %hook TabBar
// - (void)layoutSubviews {
//   %orig;
//
//   UIView *leadingTintView = [self valueForKey:@"_leadingBackgroundTintView"];
//   UIView *trailingTintView = [self valueForKey:@"_trailingBackgroundTintView"];
//   UIView *leadingBGOView = [self valueForKey:@"_leadingBackgroundOverlayView"];
//   UIView *trailingBGOView = [self valueForKey:@"_trailingBackgroundOverlayView"];
//   UIView *leadingView = [self valueForKey:@"_leadingContainer"];
//   UIView *trailingView = [self valueForKey:@"_trailingContainer"];
//
//   leadingTintView.backgroundColor = trailingTintView.backgroundColor = leadingBGOView.backgroundColor =
//   trailingBGOView.backgroundColor = [UIColor clearColor];
//   leadingView.layer.backgroundColor = trailingView.layer.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1].CGColor;
//   leadingTintView.alpha = leadingView.alpha = leadingBGOView.alpha = trailingTintView.alpha = trailingView.alpha = trailingBGOView.alpha = 1;
//
// }
// %end

// @interface TabBarItemView : UIView
// @end
// %hook TabBarItemView
// - (void)layoutSubviews {
//   %orig;
//   UILabel *titleLabel = [self valueForKey:@"_titleLabel"];
//   UILabel *titleOverlay = [self valueForKey:@"_titleOverlayLabel"];
//   UIView *titleClipperView = [self valueForKey:@"_titleClipperView"];
//   // UIImageView *closeButtonImageView = [self valueForKey:@"_closeButtonImageView"];
//   UIImageView *closeButtonOverlayImageView = [self valueForKey:@"_closeButtonOverlayImageView"];
//   // UIButton *closeButton = [self valueForKey:@"_closeButton"];
//
//   titleLabel.textColor = titleOverlay.textColor = [UIColor whiteColor];
//   titleOverlay.layer.backgroundColor = titleLabel.layer.backgroundColor = titleClipperView.layer.backgroundColor = self.layer.backgroundColor =  [UIColor clearColor].CGColor;
//   self.alpha = titleLabel.alpha = titleOverlay.alpha = titleClipperView.alpha = 1;//closeButtonImageView.alpha = closeButtonOverlayImageView.alpha = 1;
//   // closeButtonImageView.backgroundColor = [UIColor clearColor];
//   // closeButtonOverlayImageView.backgroundColor = closeButton.backgroundColor = [UIColor clearColor];
//   // closeButtonImageView.layer.backgroundColor = closeButtonOverlayImageView.layer.backgroundColor = closeButton.layer.backgroundColor = [UIColor clearColor].CGColor;
//   // [closeButtonImageView setTintColor:[UIColor colorWithWhite:1 alpha:1]];
//   // [closeButtonOverlayImageView setTintColor:[UIColor colorWithWhite:1 alpha:1]];
//   // [closeButton setTintColor:[UIColor colorWithWhite:1 alpha:1]];
//   // [closeButton.imageView setTintColor:[UIColor colorWithWhite:1 alpha:1]];
//   // closeButton.imageView.image = [UIImage imageWithContentsOfFile:@"/Library/Application Support/safaripad/closeButton@2x.png"];
//   // closeButtonImageView.image = [UIImage imageWithContentsOfFile:@"/Library/Application Support/safaripad/closeButton@2x.png"];
//   closeButtonOverlayImageView.image = [UIImage imageWithContentsOfFile:@"/Library/Application Support/safaripad/closeButton@2x.png"];
// }

// %end
%ctor {
    %init();
    if (kCFCoreFoundationVersionNumber < kCFCoreFoundationVersionNumber_iOS_10_0) {
        %init(preiOS10);
    }
    if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_11_0) {
        %init(iOS11);
    }
}
