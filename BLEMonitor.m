// BLEMonitor.m
// 宝骏云海 BLE 蓝牙监控 - Hook CoreBluetooth + 读取缓存状态

#import "BLEMonitor.h"
#import <CoreBluetooth/CoreBluetooth.h>

@implementation BJCarStatus

- (NSString *)description {
    return [NSString stringWithFormat:
        @"[电量:%ld%% 续航:%ldkm 油:%ldkm 里程:%ldkm 锁:%@ 空调:%@ 渐:%.1f°C]",
        (long)self.batterySoc, (long)self.leftMileage, (long)self.leftFuel,
        (long)self.mileage,
        self.doorLockStatus == 1 ? @"已锁" : @"未锁",
        self.acStatus == 1 ? @"开" : @"关",
        self.interiorTemperature];
}

@end

@implementation BJBLEMonitor {
    CBCentralManager *_centralManager;
    NSTimer *_statusTimer;
}

+ (instancetype)shared {
    static BJBLEMonitor *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[BJBLEMonitor alloc] init];
        instance.targetMAC = @"CC:45:A5:DA:B5:C3";
        instance.targetVIN = @"LK6ADAH92RB765125";
        instance.carStatus = [[BJCarStatus alloc] init];
    });
    return instance;
}

- (void)startMonitoring {
    NSLog(@"[BJBLE] 🚀 开始监控宝骏云海 BLE...");
    
    // 读取缓存状态
    [self readCachedStatus];
    
    // 定时刷新缓存状态 (每3秒)
    _statusTimer = [NSTimer scheduledTimerWithTimeInterval:3.0
                                                    target:self
                                                  selector:@selector(refreshStatus)
                                                  userInfo:nil
                                                   repeats:YES];
    
    // 初始化 CoreBluetooth
    dispatch_async(dispatch_get_main_queue(), ^{
        self->_centralManager = [[CBCentralManager alloc]
            initWithDelegate:nil
            queue:dispatch_get_main_queue()
            options:@{CBCentralManagerOptionShowPowerAlertKey: @NO}];
    });
}

- (void)stopMonitoring {
    [_statusTimer invalidate];
    _statusTimer = nil;
    NSLog(@"[BJBLE] ⏹ 停止监控");
}

- (void)refreshStatus {
    BJCarStatus *newStatus = [self readCachedStatus];
    if (newStatus && _statusCallback) {
        _statusCallback(newStatus);
    }
}

- (BJCarStatus *)readCachedStatus {
    // 从 UserDefaults 读取缓存的车辆状态
    // Key pattern: user_default_car_status_XXXXXX_VIN
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *dict = [defaults dictionaryRepresentation];
    
    BJCarStatus *status = _carStatus ?: [[BJCarStatus alloc] init];
    
    for (NSString *key in dict) {
        if ([key hasPrefix:@"user_default_car_status_"] && [key containsString:@"LK6ADAH92RB765125"]) {
            id value = dict[key];
            if ([value isKindOfClass:[NSDictionary class]]) {
                [self parseStatusDict:value into:status];
                status.vin = @"LK6ADAH92RB765125";
                _carStatus = status;
                _lastUpdateTime = [NSDate date];
                NSLog(@"[BJBLE] 📊 状态已更新: %@", status);
                return status;
            } else if ([value isKindOfClass:[NSString class]]) {
                // 尝试 JSON 解析
                NSData *jsonData = [(NSString *)value dataUsingEncoding:NSUTF8StringEncoding];
                if (jsonData) {
                    NSError *error;
                    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:jsonData
                                                                        options:0
                                                                          error:&error];
                    if (json && !error) {
                        [self parseStatusDict:json into:status];
                        status.vin = @"LK6ADAH92RB765125";
                        _carStatus = status;
                        _lastUpdateTime = [NSDate date];
                        NSLog(@"[BJBLE] 📊 状态已更新 (JSON): %@", status);
                        return status;
                    }
                }
            }
        }
    }
    
    // 也检查其他可能的 key 格式
    for (NSString *key in dict) {
        if ([key containsString:@"car_status"] || [key containsString:@"carStatus"]) {
            id value = dict[key];
            NSLog(@"[BJBLE] 🔍 找到候选 key: %@ = %@", key, [value description]);
        }
    }
    
    return status;
}

- (void)parseStatusDict:(NSDictionary *)dict into:(BJCarStatus *)status {
    // 安全读取数值
    #define READ_NUM(field, key) do { \
        id v = dict[key]; \
        if ([v respondsToSelector:@selector(doubleValue)]) { \
            status.field = [v doubleValue]; \
        } \
    } while(0)
    
    #define READ_INT(field, key) do { \
        id v = dict[key]; \
        if ([v respondsToSelector:@selector(integerValue)]) { \
            status.field = [v integerValue]; \
        } \
    } while(0)
    
    READ_INT(batterySoc, @"batterySoc");
    READ_NUM(leftBatteryPower, @"leftBatteryPower");
    READ_INT(leftMileage, @"leftMileage");
    READ_INT(leftFuel, @"leftFuel");
    READ_INT(mileage, @"mileage");
    READ_NUM(voltage, @"voltage");
    READ_NUM(current, @"current");
    READ_INT(batSOH, @"batSOH");
    READ_NUM(batAvgTemp, @"batAvgTemp");
    READ_NUM(lowBatVol, @"lowBatVol");
    READ_INT(doorLockStatus, @"doorLockStatus");
    READ_INT(tailDoorOpenStatus, @"tailDoorOpenStatus");
    READ_INT(windowStatus, @"windowStatus");
    READ_INT(acStatus, @"acStatus");
    READ_INT(autoGearStatus, @"autoGearStatus");
    READ_INT(charging, @"charging");
    READ_NUM(interiorTemperature, @"interiorTemperature");
    READ_NUM(tmActTemp, @"tmActTemp");
    READ_NUM(invActTemp, @"invActTemp");
    READ_NUM(latitude, @"latitude");
    READ_NUM(longitude, @"longitude");
    
    id ct = dict[@"collectTime"];
    if ([ct isKindOfClass:[NSString class]]) {
        status.collectTime = ct;
    }
    
    #undef READ_NUM
    #undef READ_INT
}

@end
