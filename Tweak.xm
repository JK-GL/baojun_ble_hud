// Tweak.xm
// 宝骏云海 BLE HUD - 调试版

#import "BLEMonitor.h"
#import "HUDViewController.h"
#import <UIKit/UIKit.h>
#import <CoreBluetooth/CoreBluetooth.h>

// ============================================================
// MARK: - CBPeripheral 数据解析 Category
// ============================================================

@interface CBPeripheral (BJBLEDataParse)
- (void)bj_handleAuthData:(NSData *)data;
- (void)bj_handleControlData:(NSData *)data;
@end

@implementation CBPeripheral (BJBLEDataParse)

- (void)bj_handleAuthData:(NSData *)data {
    if (data.length < 49) return;
    const uint8_t *bytes = (const uint8_t *)data.bytes;
    uint8_t type = bytes[1];
    NSLog(@"[BJBLE] 🔐 鉴权数据 type:0x%02X", type);
    BJBLEMonitor *monitor = [BJBLEMonitor shared];
    if (type == 0x06) monitor.bleStatus = BJBleStatusHandshaking1;
    else if (type == 0x05) { monitor.bleStatus = BJBleStatusAuthorized; monitor.isAuthorized = YES; }
}

- (void)bj_handleControlData:(NSData *)data {
    if (data.length < 49) return;
    const uint8_t *bytes = (const uint8_t *)data.bytes;
    NSLog(@"[BJBLE] 🎮 控制数据 type:0x%02X", bytes[1]);
}

@end

// ============================================================
// MARK: - 搜索所有 NSUserDefaults 的 key（调试用）
// ============================================================

static void dumpUserDefaultsKeys(void) {
    NSDictionary *dict = [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];
    NSLog(@"[BJBLE] ======== NSUserDefaults keys (%lu) ========", (unsigned long)dict.count);
    for (NSString *key in dict) {
        id val = dict[key];
        NSString *desc = [val isKindOfClass:[NSString class]] ?
            [(NSString *)val substringToIndex:MIN((int)[(NSString *)val length], 60)] :
            [val description];
        NSLog(@"[BJBLE]   %@ = %@", key, desc);
    }
    NSLog(@"[BJBLE] ============================================");
}

// ============================================================
// MARK: - App Hook - 用 load 确保最晚注入
// ============================================================

static BOOL hudShowing = NO;

static void showHUDIfNeeded(void) {
    if (hudShowing) return;
    hudShowing = YES;

    NSLog(@"[BJBLE] 🚀 showHUDIfNeeded 被调用!");

    dispatch_async(dispatch_get_main_queue(), ^{
        // 直接显示 HUD
        HUDViewController *hud = [HUDViewController shared];
        [hud show];

        // 尝试读取状态
        BJBLEMonitor *monitor = [BJBLEMonitor shared];
        BJCarStatus *status = [monitor readCachedStatus];
        if (status) {
            NSLog(@"[BJBLE] ✅ 读取到车辆状态: %@", status);
            [hud updateWithStatus:status];
        } else {
            NSLog(@"[BJBLE] ⚠️ 未读取到缓存状态，HUD 以默认值显示");
        }

        // 启动定时刷新
        [monitor startMonitoring];
    });
}

// ============================================================
// MARK: - Hook UIApplication
// ============================================================

%hook UIApplication

- (void)applicationDidBecomeActive:(UIApplication *)application {
    %orig;
    NSLog(@"[BJBLE] 📱 applicationDidBecomeActive! Bundle: %@", [[NSBundle mainBundle] bundleIdentifier]);
    dumpUserDefaultsKeys();
    showHUDIfNeeded();
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    %orig;
    NSLog(@"[BJBLE] 📱 applicationDidEnterBackground");
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    %orig;
    NSLog(@"[BJBLE] 📱 applicationWillEnterForeground");
    showHUDIfNeeded();
}

%end

// ============================================================
// MARK: - Hook FlutterAppDelegate (Flutter App)
// ============================================================

// Flutter app 可能不走传统 UIApplicationDelegate
// 尝试 hook FlutterViewController

%hook FlutterViewController

- (void)viewDidLoad {
    %orig;
    NSLog(@"[BJBLE] 🎯 FlutterViewController viewDidLoad!");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
            NSLog(@"[BJBLE] 🎯 FlutterViewController 延时 2s 后显示 HUD");
            dumpUserDefaultsKeys();
            showHUDIfNeeded();
        });
}

%end

// ============================================================
// MARK: - CoreBluetooth Hook
// ============================================================

%hook CBCentralManager

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral
    advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    %orig;
    NSString *name = peripheral.name ?: @"";
    if ([name containsString:@"E260"] || [name containsString:@"E300"] ||
        [name containsString:@"baojun"] || [name containsString:@"BLE"]) {
        NSLog(@"[BJBLE] 📡 发现BLE设备: %@ RSSI:%@", name, RSSI);
        [BJBLEMonitor shared].bleStatus = BJBleStatusSearching;
    }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    %orig;
    NSString *name = peripheral.name ?: @"";
    if ([name containsString:@"E260"] || [name containsString:@"E300"]) {
        NSLog(@"[BJBLE] 🔗 已连接: %@", name);
        BJBLEMonitor *m = [BJBLEMonitor shared];
        m.isConnected = YES;
        m.bleStatus = BJBleStatusAuthorizing;
    }
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral
                 error:(NSError *)error {
    %orig;
    NSString *name = peripheral.name ?: @"";
    if ([name containsString:@"E260"] || [name containsString:@"E300"]) {
        NSLog(@"[BJBLE] ❌ 断开: %@", name);
        BJBLEMonitor *m = [BJBLEMonitor shared];
        m.isConnected = NO;
        m.isAuthorized = NO;
        m.bleStatus = BJBleStatusDisconnected;
    }
}

%end

// ============================================================
// MARK: - CBPeripheral Hook
// ============================================================

%hook CBPeripheral

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    %orig;
    if (error) return;
    for (CBService *s in peripheral.services) {
        NSLog(@"[BJBLE] 🔧 服务: %@", s.UUID.UUIDString);
        [peripheral discoverCharacteristics:nil forService:s];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral
    didDiscoverCharacteristicsForService:(CBService *)service
                                   error:(NSError *)error {
    %orig;
    for (CBCharacteristic *c in service.characteristics) {
        NSLog(@"[BJBLE] 🔑 特征: %@ props:%lu", c.UUID.UUIDString, (unsigned long)c.properties);
        if (c.properties & CBCharacteristicPropertyNotify) {
            [peripheral setNotifyValue:YES forCharacteristic:c];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral
    didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic
                              error:(NSError *)error {
    %orig;
    if (error || !characteristic.value) return;
    NSData *data = characteristic.value;
    NSString *uuid = characteristic.UUID.UUIDString;
    NSLog(@"[BJBLE] 📩 [%@] %luB", uuid, (unsigned long)data.length);
    if ([uuid isEqualToString:@"2A6F"] || [uuid isEqualToString:@"2a6f"]) {
        [peripheral bj_handleAuthData:data];
    } else if ([uuid isEqualToString:@"2A7F"] || [uuid isEqualToString:@"2a7f"]) {
        [peripheral bj_handleControlData:data];
    }
}

%end

// ============================================================
// MARK: - NSUserDefaults Hook
// ============================================================

%hook NSUserDefaults

- (void)setObject:(id)value forKey:(NSString *)defaultName {
    %orig;
    if ([defaultName containsString:@"car_status"] || [defaultName containsString:@"carStatus"] ||
        [defaultName containsString:@"vehicle"] || [defaultName containsString:@"ble"]) {
        NSLog(@"[BJBLE] 💾 UserDefaults 写入: %@", defaultName);
        if ([value isKindOfClass:[NSDictionary class]]) {
            [[BJBLEMonitor shared] readCachedStatus];
        }
    }
}

%end

// ============================================================
// MARK: - 也 hook viewDidAppear 确保能显示
// ============================================================

%hook UIViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    // 第一次 viewDidAppear 时触发
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSLog(@"[BJBLE] 📱 第一个 UIViewController viewDidAppear!");
        showHUDIfNeeded();
    });
}

%end

// ============================================================
// MARK: - 构造函数 - 最先执行
// ============================================================

%ctor {
    NSLog(@"[BJBLE] =============================================");
    NSLog(@"[BJBLE] 🚀🚀🚀 宝骏云海 BLE HUD 插件已加载! 🚀🚀🚀");
    NSLog(@"[BJBLE] 📱 Bundle: %@", [[NSBundle mainBundle] bundleIdentifier]);
    NSLog(@"[BJBLE] 📱 可执行文件: %@", [[NSProcessInfo processInfo] processName]);
    NSLog(@"[BJBLE] =============================================");

    // 延时 3 秒后尝试显示 HUD（确保 app 完全加载）
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
            NSLog(@"[BJBLE] ⏰ 3秒延时到期，尝试显示 HUD");
            dumpUserDefaultsKeys();
            showHUDIfNeeded();
        });
}
