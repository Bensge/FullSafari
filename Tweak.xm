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

%hook TabController

- (BOOL)canAddNewTab {
    return YES;
}

%group iOS11
- (BOOL)canAddNewTabForPrivateBrowsing:(BOOL)arg1 {
    return YES;
}

- (BOOL)canAddNewTabForCurrentBrowsingMode {
    return YES;
}

- (void)setUsesTabBar:(BOOL)arg1 {
    arg1 = YES;
    %orig;
}
%end

%end

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
    // explanation: on iOS 11, if you are gonna log the whole stacktrace of the universe, you will notice that at some point,
    // apple decides in this function (or right in the previous call) whether to leave the tab bar or not based on whatever reasons they see fit
    // (aka is ipad or not or whatever). After they do all their calculations and reach a decision,
    // they do not nil the tab or touch it, but they simply do removeFromSuperview...
    // which is absolutely lovely because we can bypass that and everything's intact,
    // untouched and kept natural
    if (!self.tabController.tabBar.superview || kCFCoreFoundationVersionNumber < kCFCoreFoundationVersionNumber_iOS_11_0) {
        fakeHorizontalSizeClass = YES;
        %orig;
        fakeHorizontalSizeClass = NO;
    }
}

// This is iOS 11+ as well and needed but it shouldn't need grouping, I very much doubt it even exists in lower versions
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
%property (nonatomic, retain) UIBarButtonItem *addTabItemManual;
// Force-add the "add tab" button to the toolbar
- (NSMutableArray *)defaultItems {
    NSMutableArray *orig = %orig;
    if (kCFCoreFoundationVersionNumber < kCFCoreFoundationVersionNumber_iOS_11_2) {
      GestureRecognizingBarButtonItem *addTabItem = MSHookIvar<GestureRecognizingBarButtonItem *>(self, "_addTabItem");
      if (!addTabItem || ![orig containsObject:addTabItem]) {
          if (!addTabItem) {
              // Recreate the "add tab" button for iOS versions that don't do that by default on iPhone models
              addTabItem = [[NSClassFromString(@"GestureRecognizingBarButtonItem") alloc] initWithImage:[[UIImage imageNamed:@"AddTab"] retain] style:0 target:[self valueForKey:@"_browserDelegate"] action:@selector(addTabFromButtonBar)];
              UILongPressGestureRecognizer *recognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(_addTabLongPressRecognized:)];
              recognizer.allowableMovement = 3.0;
              addTabItem.gestureRecognizer = recognizer;
          }
          // iOS 11 doubles the + button because of this and the thing below
          // Also, SafariPlus ditches your "+" button on iOS 11 - perhaps of this bypass, perhaps not; todo: make it SafariPlus compatible, sometime later on perhaps
          if (kCFCoreFoundationVersionNumber < kCFCoreFoundationVersionNumber_iOS_11_0) {
              [orig addObject:addTabItem];
          }


          NSMutableDictionary *defaultItemsForToolbarSize = [self valueForKey:@"_defaultItemsForToolbarSize"];
          if (defaultItemsForToolbarSize) {
              [self setValue:addTabItem forKey:@"_addTabItem"];
              if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_11_0) {
                  UIBarButtonItem *space = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil] autorelease];
                  [MSHookIvar<NSMutableDictionary *>(self, "_defaultItemsForToolbarSize")[@([self toolbarSize])] addObject:space];
              }
              [MSHookIvar<NSMutableDictionary *>(self, "_defaultItemsForToolbarSize")[@([self toolbarSize])] addObject:[self valueForKey:@"_addTabItem"]];
          }


          if (kCFCoreFoundationVersionNumber > kCFCoreFoundationVersionNumber_iOS_11_0) {
              // Replace fixed-width spacers by flexible ones again to circumvent layout issues
              for (UIBarButtonItem *item in [orig.copy autorelease]) {
                  if ([item isSystemItem] && [item systemItem] == UIBarButtonSystemItemFixedSpace && [item width] > 0.1) {
                      NSUInteger indexOfItem = [orig indexOfObject:item];
                      if (indexOfItem != NSNotFound)
                          [orig replaceObjectAtIndex:indexOfItem withObject:[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil] autorelease]];
                  }
              }
          }
      }
    }
    else {
      //LonestarX - This gon' need some testing for iOS 11 portrait/landscape - iOS 12 portrait/landscape but idk, at first glance it looks ok; PS: no idea how it is on 11.4, would also need testing.
      UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
      if (kCFCoreFoundationVersionNumber > 1452.23 && [UIApplication sharedApplication].statusBarOrientation != UIInterfaceOrientationPortrait) {
        return orig;
      }
      else if (kCFCoreFoundationVersionNumber < 1452.23 && UIInterfaceOrientationIsLandscape(orientation)) {
        return orig;
      }
      //iOS 11.2.x - 11.3.1 implementation - LonestarX
      //NOTE: this part was a bitch to work out, I've spent at least 5 hours toying with the freaking toolbar because it kept rejecting new items. tread safely around this code
      //since AAPL decided to screw me over and remove _addTabItem ivar, we're just gonna do a MITM grab&swap
      //bar items are refreshed upon this call and it appears there's 2 sets, one for portrait and one for landscape, hence why we don't need to remove anything when switching from one to another
      NSMutableDictionary *defaultItemsForToolbarSize = [self valueForKey:@"_defaultItemsForToolbarSize"];
      NSMutableArray *items = [[defaultItemsForToolbarSize objectForKey:[[defaultItemsForToolbarSize allKeys] firstObject]] mutableCopy]; //grabbing the current items, don't switch to mshookivar, it causes trouble
        if (![items containsObject:self.addTabItemManual]) {
          //doing all them tasty init here so we save up memory by not spamming object creation every call
          TabController *tbc = [[self valueForKey:@"_browserDelegate"] valueForKey:@"_tabController"];
          UILongPressGestureRecognizer *recognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:tbc action:@selector(_addTabLongPressRecognized:)];
          UIImage *addTabImage;
          if (kCFCoreFoundationVersionNumber < 1452.23) { //if iOS < 12
            addTabImage = [UIImage imageNamed:@"AddTab"];
          }
          else {
            addTabImage = [UIImage imageNamed:@"AddTab" inBundle:[NSBundle bundleWithPath:@"/System/Library/Frameworks/SafariServices.framework"] compatibleWithTraitCollection:nil];
            //LonestarX: dem crooks moved the addTab image (and possibly other assets) from the MobileSafari app to SafariServices framework. possibly in an attempt to shift functionality to a macos/iOS framework. idk, it's Appel, who knows. idk where this is on 11.4, feel free to test
          }
          self.addTabItemManual = [[UIBarButtonItem alloc] initWithImage:[addTabImage retain] style:0 target:[self valueForKey:@"_browserDelegate"] action:@selector(openNewTab)];
          NSMutableArray *gestures = [[self.addTabItemManual valueForKey:@"_gestureRecognizers"] mutableCopy];
          [gestures addObject:recognizer];
          [self.addTabItemManual setValue:gestures forKey:@"_gestureRecognizers"];
          UIBarButtonItem *space = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil] autorelease];
          [items addObject:space];
          [items addObject:self.addTabItemManual];
        }
        [defaultItemsForToolbarSize setObject:items forKey:[[defaultItemsForToolbarSize allKeys] firstObject]];
        [self setValue:defaultItemsForToolbarSize forKey:@"_defaultItemsForToolbarSize"]; //putting the shizzle back where we took it from. i repeat, don't use mshookivar, 1131 doesn't like it
        orig = items;

        if (kCFCoreFoundationVersionNumber > kCFCoreFoundationVersionNumber_iOS_11_0) {
            // Replace fixed-width spacers by flexible ones again to circumvent layout issues
            for (UIBarButtonItem *item in [orig.copy autorelease]) {
                if ([item isSystemItem] && [item systemItem] == UIBarButtonSystemItemFixedSpace && [item width] > 0.1) {
                    NSUInteger indexOfItem = [orig indexOfObject:item];
                    if (indexOfItem != NSNotFound)
                        [orig replaceObjectAtIndex:indexOfItem withObject:[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil] autorelease]];
                }
            }
        }
    }
    return orig;
}

- (void)test {
  NSLog(@"BEEP");
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

- (UIView *)tiltedTabView: (UIView *)arg1 borrowContentViewForItem: (id)arg2 withTopBackdropView:(id *)arg3 ofHeight:(CGFloat)height {
    height += [objc_getClass("TabBar") defaultHeight];
    return %orig;
}

%end


%ctor {
    %init();
    if (kCFCoreFoundationVersionNumber < kCFCoreFoundationVersionNumber_iOS_10_0) {
        %init(preiOS10);
    }
    if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_11_0) {
        %init(iOS11);
    }
}
