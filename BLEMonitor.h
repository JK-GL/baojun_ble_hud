// BLEMonitor.h
// 宝骏云海 BLE 蓝牙监控模块

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

NS_ASSUME_NONNULL_BEGIN

// BLE 连接状态
typedef NS_ENUM(NSInteger, BJBleStatus) {
    BJBleStatusDefault = 0,
    BJBleStatusSearching,
    BJBleStatusAuthorizing,
    BJBleStatusHandshaking1,
    BJBleStatusHandshaking2,
    BJBleStatusAuthorized,
    BJBleStatusDisconnected
};

// 车辆状态数据
@interface BJCarStatus : NSObject
@property (nonatomic, assign) NSInteger batterySoc;        // 电量 %
@property (nonatomic, assign) double leftBatteryPower;     // 剩余电量 kWh
@property (nonatomic, assign) NSInteger leftMileage;       // 纯电续航 km
@property (nonatomic, assign) NSInteger leftFuel;          // 燃油续航 km
@property (nonatomic, assign) NSInteger mileage;           // 总里程 km
@property (nonatomic, assign) double voltage;              // 电池电压 V
@property (nonatomic, assign) double current;              // 电池电流 A
@property (nonatomic, assign) NSInteger batSOH;            // 电池健康度 %
@property (nonatomic, assign) double batAvgTemp;           // 电池平均温度
@property (nonatomic, assign) double lowBatVol;            // 低压电池电压
@property (nonatomic, assign) NSInteger doorLockStatus;    // 门锁 0=解锁 1=已锁
@property (nonatomic, assign) NSInteger tailDoorOpenStatus;// 尾门
@property (nonatomic, assign) NSInteger windowStatus;      // 车窗
@property (nonatomic, assign) NSInteger acStatus;          // 空调
@property (nonatomic, assign) NSInteger autoGearStatus;    // 档位
@property (nonatomic, assign) NSInteger charging;          // 充电状态
@property (nonatomic, assign) double interiorTemperature;  // 车内温度
@property (nonatomic, assign) double tmActTemp;            // 电机温度
@property (nonatomic, assign) double invActTemp;           // 逆变器温度
@property (nonatomic, assign) double latitude;
@property (nonatomic, assign) double longitude;
@property (nonatomic, copy) NSString *collectTime;
@property (nonatomic, copy) NSString *vin;
@end

// BLE 监控器
@interface BJBLEMonitor : NSObject
@property (nonatomic, assign) BJBleStatus bleStatus;
@property (nonatomic, strong) BJCarStatus *carStatus;
@property (nonatomic, copy) NSString *targetMAC;
@property (nonatomic, copy) NSString *targetVIN;
@property (nonatomic, assign) BOOL isConnected;
@property (nonatomic, assign) BOOL isAuthorized;
@property (nonatomic, strong) NSDate *lastUpdateTime;
@property (nonatomic, copy) void (^statusCallback)(BJCarStatus *status);
@property (nonatomic, copy) void (^bleStatusCallback)(BJBleStatus status);

+ (instancetype)shared;
- (void)startMonitoring;
- (void)stopMonitoring;
- (BJCarStatus *)readCachedStatus;
@end

NS_ASSUME_NONNULL_END
