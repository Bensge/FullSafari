#import <substrate.h>
#import "Private.h"

BOOL fakeHorizontalSizeClass = NO;
BOOL fakeUserInterfaceIdiom = NO;

%hook UIDevice

- (UIUserInterfaceIdiom)userInterfaceIdiom
{
    return fakeUserInterfaceIdiom ? UIUserInterfaceIdiomPad : %orig;
}

%end

%hook UITraitCollection

- (UIUserInterfaceSizeClass)horizontalSizeClass
{
    return fakeHorizontalSizeClass ? UIUserInterfaceSizeClassRegular : %orig;
}

%end

%hook NSUserDefaults

- (BOOL)boolForKey: (NSString *)key
{
    return [key isEqualToString:@"ShowTabBar"] ? YES : %orig;
}

%end

%hook TabController

- (BOOL)canAddNewTab
{
    return YES;
}

%end

%hook BrowserController

- (BOOL)_shouldShowTabBar
{
    return YES;
}

- (CGFloat)_navigationBarOverlapHeight {
    fakeUserInterfaceIdiom = YES;
    CGFloat orig = %orig;
    fakeUserInterfaceIdiom = NO;
    return orig;
}

- (void)updateUsesTabBar {
    fakeHorizontalSizeClass = YES;
    %orig;
    fakeHorizontalSizeClass = NO;
}

%end

%hook BrowserToolbar

//Force-add the "add tab" button to the toolbar
- (NSMutableArray *)defaultItems
{
    NSMutableArray *orig = %orig;
    GestureRecognizingBarButtonItem *addTabItem = MSHookIvar<GestureRecognizingBarButtonItem *>(self, "_addTabItem");

    if (!addTabItem || ![orig containsObject:addTabItem]) {
        if (!addTabItem) {
            //Recreate the "add tab" button for iOS versions that don't do that by default on iPhone models
            addTabItem = [[NSClassFromString(@"GestureRecognizingBarButtonItem") alloc] initWithImage:[[UIImage imageNamed:@"AddTab"] retain] style:0 target:[self valueForKey:@"_browserDelegate"] action:@selector(addTabFromButtonBar)];
            UILongPressGestureRecognizer *recognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(_addTabLongPressRecognized:)];
            recognizer.allowableMovement = 3.0;
            addTabItem.gestureRecognizer = recognizer;
        }
        [orig addObject:addTabItem];

        NSMutableDictionary *defaultItemsForToolbarSize = [self valueForKey:@"_defaultItemsForToolbarSize"];
        if (defaultItemsForToolbarSize) {
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

-(UIView *)tiltedTabView: (UIView *)arg1 borrowContentViewForItem: (id)arg2 withTopBackdropView: (id *)arg3 ofHeight: (CGFloat)height
{
    height += [objc_getClass("TabBar") defaultHeight];
    return %orig;
}

%end

%ctor {
    %init();
}
