#import <substrate.h>

BOOL fakeHorizontalSizeClass = NO;
BOOL fakeUserInterfaceIdiom = NO;
BOOL stopNarrowLayout = NO;
BOOL dontUseNarrowLayout = NO;

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

//Force-add the "add tab" button to the toolbar
@interface UIBarButtonItem (Extend)
- (BOOL)isSystemItem;
- (UIBarButtonSystemItem)systemItem;
@end

//Recreate the "add tab" button for iOS versions that don't do that by default on iPhone models
@interface GestureRecognizingBarButtonItem : UIBarButtonItem
@property (retain, nonatomic) UIGestureRecognizer *gestureRecognizer;
@end

%hook UIViewController

- (BOOL)safari_isHorizontallyConstrained
{
	return YES;
}

%end

%hook TabController

- (BOOL)canAddNewTab
{
	return YES;
}

- (BOOL)usesTabBar
{
	return YES;
}

- (void)setUsesTabBar:(BOOL)arg
{
	%orig(YES);
}

%end

%hook BrowserController

- (BOOL)_shouldUseNarrowLayout
{
	return dontUseNarrowLayout ? NO : %orig;
}

- (CGFloat)_navigationBarOverlapHeight
{
	fakeUserInterfaceIdiom = YES;
	CGFloat orig = %orig;
	fakeUserInterfaceIdiom = NO;
	return orig;
}

- (void)dynamicBarAnimatorOutputsDidChange:(id)arg1
{
	dontUseNarrowLayout = YES;
	%orig;
	dontUseNarrowLayout = NO;
}

- (BOOL)usesNarrowLayout
{
	return stopNarrowLayout ? NO : %orig;
}

- (void)_updateUsesNarrowLayout
{
	stopNarrowLayout = YES;
	fakeUserInterfaceIdiom = YES;
	%orig;
	stopNarrowLayout = NO;
	fakeUserInterfaceIdiom = NO;
}

- (void)updateUsesTabBar
{
	fakeHorizontalSizeClass = YES;
	%orig;
	fakeHorizontalSizeClass = NO;
}

- (void)updateShowingTabBarAnimated:(BOOL)arg1
{
	fakeHorizontalSizeClass = YES;
	%orig;
	fakeHorizontalSizeClass = NO;
}

%end

%hook BrowserToolbar

- (void)setItems:(NSArray *)items animated:(BOOL)arg2
{
	UIBarButtonItem *addTabItem = [self valueForKey:@"_addTabItem"];
	if (addTabItem == nil) {
		// Have to recreate it because Safari didn't do for us
		MSHookIvar<GestureRecognizingBarButtonItem *>(self, "_addTabItem") = [[NSClassFromString(@"GestureRecognizingBarButtonItem") alloc] initWithImage:[[UIImage imageNamed:@"AddTab"] retain] style:0 target:[self valueForKey:@"_browserDelegate"] action:@selector(addTabFromButtonBar)];
		UILongPressGestureRecognizer *recognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(_addTabLongPressRecognized:)];
		recognizer.allowableMovement = 3.0;
		MSHookIvar<GestureRecognizingBarButtonItem *>(self, "_addTabItem").gestureRecognizer = recognizer;
		addTabItem = [self valueForKey:@"_addTabItem"];
	}
	if (![items containsObject:addTabItem]) {
		NSMutableArray *newItems = [items mutableCopy];

		// Replace fixed spacers with flexible ones
		for (UIBarButtonItem *item in [newItems.copy autorelease]) {
			if ([item isSystemItem] && [item systemItem] == UIBarButtonSystemItemFixedSpace && [item width] > 0.1) {
				NSUInteger indexOfItem = [items indexOfObject:item];
				if (indexOfItem != NSNotFound)
					[newItems replaceObjectAtIndex:indexOfItem withObject:[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil] autorelease]];
			}
		}
	
		UIBarButtonItem *spacer = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
		[newItems addObject:spacer];
		[newItems addObject:addTabItem];

		items = [newItems copy];
		[newItems release];
		[spacer release];
	}
	%orig(items, arg2);
}

%end

%ctor {
	%init();
}