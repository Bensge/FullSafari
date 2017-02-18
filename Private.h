@interface BrowserToolbar : NSObject
- (int)toolbarSize;
@end

@interface UIBarButtonItem (Extend)
- (BOOL)isSystemItem;
- (UIBarButtonSystemItem)systemItem;
@end

@interface GestureRecognizingBarButtonItem : UIBarButtonItem
@property (retain, nonatomic) UIGestureRecognizer *gestureRecognizer;
@end