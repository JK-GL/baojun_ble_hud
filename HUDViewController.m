// HUDViewController.m
// 宝骏云海 车辆状态悬浮窗 - 可拖拽、可展开

#import "HUDViewController.h"
#import "BLEMonitor.h"

@interface HUDViewController ()
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *socLabel;
@property (nonatomic, strong) UILabel *mileageLabel;
@property (nonatomic, strong) UILabel *doorLabel;
@property (nonatomic, strong) UILabel *acLabel;
@property (nonatomic, strong) UILabel *tempLabel;
@property (nonatomic, strong) UILabel *detailLabel;
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong) UIView *batteryBar;
@property (nonatomic, strong) UIView *batteryFill;
@property (nonatomic, strong) UIStackView *detailStack;
@property (nonatomic, assign) CGPoint dragOffset;
@property (nonatomic, strong) UITapGestureRecognizer *tapGesture;
@property (nonatomic, strong) UIPanGestureRecognizer *panGesture;
@end

@implementation HUDViewController

static HUDViewController *_shared = nil;

+ (instancetype)shared {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _shared = [[HUDViewController alloc] init];
    });
    return _shared;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    [self setupHUD];
}

- (void)setupHUD {
    // 主 HUD 容器
    CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
    CGFloat x = screenWidth - 180;
    CGFloat y = 100;
    
    _hudView = [[UIView alloc] initWithFrame:CGRectMake(x, y, 170, 120)];
    _hudView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.85];
    _hudView.layer.cornerRadius = 16;
    _hudView.layer.borderWidth = 1;
    _hudView.layer.borderColor = [[UIColor colorWithRed:0.2 green:0.8 blue:0.4 alpha:0.6] CGColor];
    _hudView.layer.shadowColor = [UIColor blackColor].CGColor;
    _hudView.layer.shadowOffset = CGSizeMake(0, 4);
    _hudView.layer.shadowRadius = 12;
    _hudView.layer.shadowOpacity = 0.5;
    _hudView.clipsToBounds = NO;
    _hudView.hidden = YES;
    
    // 标题栏
    _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 6, 150, 18)];
    _titleLabel.text = @"🚗 宝骏云海";
    _titleLabel.textColor = [UIColor whiteColor];
    _titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [_hudView addSubview:_titleLabel];
    
    // 电量进度条背景
    UIView *barBg = [[UIView alloc] initWithFrame:CGRectMake(10, 28, 150, 8)];
    barBg.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.15];
    barBg.layer.cornerRadius = 4;
    [_hudView addSubview:barBg];
    
    // 电量进度条填充
    _batteryFill = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 75, 8)];
    _batteryFill.backgroundColor = [UIColor colorWithRed:0.2 green:0.8 blue:0.4 alpha:1.0];
    _batteryFill.layer.cornerRadius = 4;
    [barBg addSubview:_batteryFill];
    
    // 电量标签
    _socLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 38, 150, 16)];
    _socLabel.text = @"⚡ --%";
    _socLabel.textColor = [UIColor colorWithRed:0.2 green:0.8 blue:0.4 alpha:1.0];
    _socLabel.font = [UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightMedium];
    [_hudView addSubview:_socLabel];
    
    // 续航标签
    _mileageLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 54, 150, 16)];
    _mileageLabel.text = @"🛣️ 纯电: --km  油: --km";
    _mileageLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.9];
    _mileageLabel.font = [UIFont monospacedDigitSystemFontOfSize:10 weight:UIFontWeightRegular];
    [_hudView addSubview:_mileageLabel];
    
    // 车门/空调行
    _doorLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 70, 75, 16)];
    _doorLabel.text = @"🔒 已锁";
    _doorLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.8];
    _doorLabel.font = [UIFont systemFontOfSize:10];
    [_hudView addSubview:_doorLabel];
    
    _acLabel = [[UILabel alloc] initWithFrame:CGRectMake(85, 70, 75, 16)];
    _acLabel.text = @"❄️ --";
    _acLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.8];
    _acLabel.font = [UIFont systemFontOfSize:10];
    [_hudView addSubview:_acLabel];
    
    // 温度标签
    _tempLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 86, 150, 14)];
    _tempLabel.text = @"🌡️ 车内: --°C  电池: --°C";
    _tempLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.6];
    _tempLabel.font = [UIFont systemFontOfSize:9];
    [_hudView addSubview:_tempLabel];
    
    // 更新时间
    _timeLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 100, 150, 14)];
    _timeLabel.text = @"🕐 --:--:--";
    _timeLabel.textColor = [[UIColor whiteColor] colorWithAlphaComponent:0.4];
    _timeLabel.font = [UIFont systemFontOfSize:8];
    [_hudView addSubview:_timeLabel];
    
    // 手势
    _tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    [_hudView addGestureRecognizer:_tapGesture];
    
    _panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [_hudView addGestureRecognizer:_panGesture];
    
    [self.view addSubview:_hudView];
}

- (void)show {
    dispatch_async(dispatch_get_main_queue(), ^{
        self->_hudView.hidden = NO;
        self->_hudView.alpha = 0;
        [UIView animateWithDuration:0.3 animations:^{
            self->_hudView.alpha = 1.0;
        }];
    });
}

- (void)hide {
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.3 animations:^{
            self->_hudView.alpha = 0;
        } completion:^(BOOL finished) {
            self->_hudView.hidden = YES;
        }];
    });
}

- (void)updateWithStatus:(BJCarStatus *)status {
    if (!status) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        // 电量
        NSInteger soc = status.batterySoc;
        self->_socLabel.text = [NSString stringWithFormat:@"⚡ %ld%%  %.1fkWh", (long)soc, status.leftBatteryPower];
        
        // 电量条颜色
        CGFloat ratio = soc / 100.0;
        if (ratio > 0.5) {
            self->_batteryFill.backgroundColor = [UIColor colorWithRed:0.2 green:0.8 blue:0.4 alpha:1.0];
        } else if (ratio > 0.2) {
            self->_batteryFill.backgroundColor = [UIColor colorWithRed:1.0 green:0.7 blue:0.0 alpha:1.0];
        } else {
            self->_batteryFill.backgroundColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:1.0];
        }
        [UIView animateWithDuration:0.5 animations:^{
            CGRect frame = self->_batteryFill.frame;
            frame.size.width = 150 * ratio;
            self->_batteryFill.frame = frame;
        }];
        
        // 续航
        self->_mileageLabel.text = [NSString stringWithFormat:@"🛣️ 电:%ldkm 油:%ldkm 总:%ldkm",
            (long)status.leftMileage, (long)status.leftFuel, (long)status.mileage];
        
        // 车门
        NSString *doorIcon = status.doorLockStatus == 1 ? @"🔒" : @"🔓";
        NSString *doorText = status.doorLockStatus == 1 ? @"已锁" : @"未锁";
        self->_doorLabel.text = [NSString stringWithFormat:@"%@ %@", doorIcon, doorText];
        
        // 空调
        NSString *acText = status.acStatus == 1 ? @"开" : @"关";
        self->_acLabel.text = [NSString stringWithFormat:@"❄️ %@", acText];
        
        // 温度
        self->_tempLabel.text = [NSString stringWithFormat:@"🌡️ 内%.0f°C 电%.0f°C 电驱%.0f°C",
            status.interiorTemperature, status.batAvgTemp, status.invActTemp];
        
        // 时间
        if (status.collectTime) {
            self->_timeLabel.text = [NSString stringWithFormat:@"🕐 %@", status.collectTime];
        }
    });
}

#pragma mark - Gestures

- (void)handleTap:(UITapGestureRecognizer *)gesture {
    _isExpanded = !_isExpanded;
    
    [UIView animateWithDuration:0.3 animations:^{
        if (self.isExpanded) {
            CGRect frame = self->_hudView.frame;
            frame.size.height = 200;
            self->_hudView.frame = frame;
            self->_tempLabel.hidden = NO;
            self->_timeLabel.hidden = NO;
        } else {
            CGRect frame = self->_hudView.frame;
            frame.size.height = 120;
            self->_hudView.frame = frame;
        }
    }];
}

- (void)handlePan:(UIPanGestureRecognizer *)gesture {
    CGPoint location = [gesture locationInView:self.view];
    
    if (gesture.state == UIGestureRecognizerStateBegan) {
        _dragOffset = CGPointMake(location.x - _hudView.frame.origin.x,
                                  location.y - _hudView.frame.origin.y);
    } else if (gesture.state == UIGestureRecognizerStateChanged) {
        CGFloat newX = location.x - _dragOffset.x;
        CGFloat newY = location.y - _dragOffset.y;
        
        // 边界限制
        CGRect screen = [UIScreen mainScreen].bounds;
        newX = MAX(0, MIN(newX, screen.size.width - _hudView.frame.size.width));
        newY = MAX(40, MIN(newY, screen.size.height - _hudView.frame.size.height - 40));
        
        _hudView.frame = CGRectMake(newX, newY, _hudView.frame.size.width, _hudView.frame.size.height);
    }
}

@end
