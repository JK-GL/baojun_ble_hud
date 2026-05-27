// HUDViewController.h
// 宝骏云海 车辆状态悬浮窗

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface HUDViewController : UIViewController
@property (nonatomic, strong) UIView *hudView;
@property (nonatomic, assign) BOOL isExpanded;
+ (instancetype)shared;
- (void)show;
- (void)hide;
- (void)updateWithStatus:(id)status;
@end

NS_ASSUME_NONNULL_END
