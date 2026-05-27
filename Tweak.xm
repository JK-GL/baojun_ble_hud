// Tweak.xm
// 宝骏云海 BLE 车辆状态悬浮窗
// Hook CoreBluetooth + 读取缓存状态 + 显示 HUD

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
    if (type == 0x06) {
        monitor.bleStatus = BJBleStatusHandshaking1;
    } else if (type == 0x05) {
        monitor.bleStatus = BJBleStatusAuthorized;
        monitor.isAuthorized = YES;
    }
}

- (void)bj_handleControlData:(NSData *)data {
    if (data.length < 49) return;
    const uint8_t *bytes = (const uint8_t *)data.bytes;
    NSLog(@"[BJBLE] 🎮 控制数据 type:0x%02X", bytes[1]);
}

@end

// ============================================================
// MARK: - App 生命周期 Hook
// ============================================================

%hook UIApplication

- (void)applicationDidBecomeActive:(UIApplication *)application {
    %orig;
    
    NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
    NSLog(@"[BJBLE] 📱 App 激活: %@", bundleId);
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
        
        BJBLEMonitor *monitor = [BJBLEMonitor shared];
        HUDViewController *hud = [HUDViewController shared];
        
        monitor.statusCallback = ^(BJCarStatus *status) {
            [hud updateWithStatus:status];
        };
        
        [monitor startMonitoring];
        [hud show];
        
        NSLog(@"[BJBLE] ✅ HUD 已启动");
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
    if ([name containsString:@"E260-BLE"] || [name containsString:@"E300-BLE"]) {
        NSLog(@"[BJBLE] 📡 发现宝骏设备: %@ RSSI:%@", name, RSSI);
        [BJBLEMonitor shared].bleStatus = BJBleStatusSearching;
    }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    %orig;
    NSString *name = peripheral.name ?: @"";
    if ([name containsString:@"E260-BLE"] || [name containsString:@"E300-BLE"]) {
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
    if ([name containsString:@"E260-BLE"] || [name containsString:@"E300-BLE"]) {
        NSLog(@"[BJBLE] ❌ 断开: %@", name);
        BJBLEMonitor *m = [BJBLEMonitor shared];
        m.isConnected = NO;
        m.isAuthorized = NO;
        m.bleStatus = BJBleStatusDisconnected;
    }
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral
                 error:(NSError *)error {
    %orig;
    NSLog(@"[BJBLE] ⚠️ 连接失败: %@", peripheral.name);
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
    const uint8_t *bytes = (const uint8_t *)data.bytes;
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
    if ([defaultName containsString:@"car_status"] || [defaultName containsString:@"carStatus"]) {
        NSLog(@"[BJBLE] 💾 车辆状态更新: %@", defaultName);
        [[BJBLEMonitor shared] readCachedStatus];
    }
}

%end

// ============================================================
// MARK: - 初始化
// ============================================================

%ctor {
    NSLog(@"[BJBLE] 🚀 宝骏云海 BLE HUD 插件已加载!");
    NSLog(@"[BJBLE] 📱 Bundle: %@", [[NSBundle mainBundle] bundleIdentifier]);
}
