//Enable tab bar by always faking regular horizontal size class
%hook UITraitCollection

- (long long)horizontalSizeClass
{
	return UIUserInterfaceSizeClassRegular;
}

%end

//Force-add the "add tab" button to the toolbar
@interface UIBarButtonItem ()
- (BOOL)isSystemItem;
- (UIBarButtonSystemItem)systemItem;
@end

%hook BrowserToolbar

-(void)setAddTabEnabled:(BOOL)arg1
{
	%orig(YES);
}

-(void)setItems:(NSArray *)items animated:(BOOL)arg2
{
	%log;
	UIBarButtonItem *addTabItem = [self valueForKey:@"_addTabItem"];
	if (![items containsObject:addTabItem])
	{
		NSMutableArray *newItems = [items mutableCopy];

		//Replace fixed spacers with flexible ones
		for (UIBarButtonItem *item in [newItems.copy autorelease])
		{
			if ([item isSystemItem] && [item systemItem] == UIBarButtonSystemItemFixedSpace && [item width] > 0.1)
			{
				[newItems replaceObjectAtIndex:[items indexOfObject:item] withObject:[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil] autorelease]];
			}
		}
		
		UIBarButtonItem *spacer = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
		[newItems addObject:spacer];
		[newItems addObject:addTabItem];

		items = [newItems copy];
		[newItems release];
		[spacer release];
	}

	%orig(items,arg2);
}

%end

#if DEBUG
%group Debug
%hook UIBarButtonItem

- (NSString *)description
{
	if ([[self valueForKey:@"_flexible"] boolValue])
	{
		return [NSString stringWithFormat:@"<%@ %p FLEXIBLE>",NSStringFromClass(self.class),self];
	}
	else if ((BOOL)[self isSystemItem] && (int)[self systemItem] == UIBarButtonSystemItemFixedSpace)
	{
		return [NSString stringWithFormat:@"<%@ %p FIXED (%f)>",NSStringFromClass(self.class),self,[[self valueForKey:@"_width"] doubleValue]];
	}
	else
		return %orig;
}

%end

/*%hook BrowserController

//-(void)updateUsesTabBar
//{
//
//}

-(void)setShowingTabBar:(char)arg1
{
	%orig(YES);
}

%end

%hook TabController

-(char)usesTabBar
{
	%orig;
	return YES;
}

-(void)setUsesTabBar:(char)arg1
{
	%orig(YES);
}

%end

%hook UIDevice
-(UIUserInterfaceIdiom)userInterfaceIdiom
{
	return UIUserInterfaceIdiomPad;
	return %orig;
}
%end
*/
%end
#endif

%ctor {
	%init();
#if DEBUG
	%init(Debug);
#endif
}