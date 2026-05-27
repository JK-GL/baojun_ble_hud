// Tweak.xm
// 宝骏云海 BLE 车辆状态悬浮窗
// Hook CoreBluetooth + 读取缓存状态 + 显示 HUD

#import "BLEMonitor.h"
#import "HUDViewController.h"
#import <UIKit/UIKit.h>
#import <CoreBluetooth/CoreBluetooth.h>

// ============================================================
// MARK: - App 生命周期 Hook
// ============================================================

%hook UIApplication

- (void)applicationDidBecomeActive:(UIApplication *)application {
    %orig;
    
    NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
    NSLog(@"[BJBLE] 📱 App 激活: %@", bundleId);
    
    // 启动 BLE 监控和 HUD
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
        
        BJBLEMonitor *monitor = [BJBLEMonitor shared];
        HUDViewController *hud = [HUDViewController shared];
        
        // 注册状态回调
        monitor.statusCallback = ^(BJCarStatus *status) {
            [hud updateWithStatus:status];
        };
        
        // 启动监控
        [monitor startMonitoring];
        
        // 显示 HUD
        [hud show];
        
        NSLog(@"[BJBLE] ✅ HUD 已启动");
    });
}

- (void)applicationWillResignActive:(UIApplication *)application {
    %orig;
    // 不停止监控，保持后台状态读取
}

%end

// ============================================================
// MARK: - CoreBluetooth Hook - 监控 BLE 扫描和连接
// ============================================================

%hook CBCentralManager

// 监控扫描到的设备
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral
    advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    
    %orig;
    
    NSString *name = peripheral.name ?: @"";
    NSString *identfier = peripheral.identifier.UUIDString ?: @"";
    
    // 检测宝骏 BLE 设备
    if ([name containsString:@"E260-BLE"] || [name containsString:@"E300-BLE"] ||
        [name containsString:@"baojun"] || [name containsString:@"BAOJUN"]) {
        
        NSLog(@"[BJBLE] 📡 发现宝骏设备: %@ (%@) RSSI:%@", name, identfier, RSSI);
        
        BJBLEMonitor *monitor = [BJBLEMonitor shared];
        monitor.bleStatus = BJBleStatusSearching;
        
        if (monitor.bleStatusCallback) {
            monitor.bleStatusCallback(BJBleStatusSearching);
        }
    }
}

// 监控连接状态
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    %orig;
    
    NSString *name = peripheral.name ?: @"";
    if ([name containsString:@"E260-BLE"] || [name containsString:@"E300-BLE"]) {
        NSLog(@"[BJBLE] 🔗 已连接: %@", name);
        
        BJBLEMonitor *monitor = [BJBLEMonitor shared];
        monitor.isConnected = YES;
        monitor.bleStatus = BJBleStatusAuthorizing;
    }
}

// 监控断开连接
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral
                 error:(NSError *)error {
    %orig;
    
    NSString *name = peripheral.name ?: @"";
    if ([name containsString:@"E260-BLE"] || [name containsString:@"E300-BLE"]) {
        NSLog(@"[BJBLE] ❌ 断开连接: %@", name);
        
        BJBLEMonitor *monitor = [BJBLEMonitor shared];
        monitor.isConnected = NO;
        monitor.isAuthorized = NO;
        monitor.bleStatus = BJBleStatusDisconnected;
    }
}

// 监控连接失败
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral
                 error:(NSError *)error {
    %orig;
    
    NSLog(@"[BJBLE] ⚠️ 连接失败: %@ - %@", peripheral.name, error.localizedDescription);
}

%end

// ============================================================
// MARK: - CBPeripheral Hook - 监控 BLE 数据交互
// ============================================================

%hook CBPeripheral

// 监控发现服务
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    %orig;
    
    if (error) {
        NSLog(@"[BJBLE] ⚠️ 发现服务失败: %@", error.localizedDescription);
        return;
    }
    
    for (CBService *service in peripheral.services) {
        NSLog(@"[BJBLE] 🔧 发现服务: %@", service.UUID.UUIDString);
        
        // 发现特征
        [peripheral discoverCharacteristics:nil forService:service];
    }
}

// 监控发现特征
- (void)peripheral:(CBPeripheral *)peripheral
    didDiscoverCharacteristicsForService:(CBService *)service
                                   error:(NSError *)error {
    %orig;
    
    for (CBCharacteristic *characteristic in service.characteristics) {
        NSLog(@"[BJBLE] 🔑 特征: %@ (properties: %lu)",
            characteristic.UUID.UUIDString, (unsigned long)characteristic.properties);
        
        // 订阅通知
        if (characteristic.properties & CBCharacteristicPropertyNotify) {
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
            NSLog(@"[BJBLE] 📢 已订阅通知: %@", characteristic.UUID.UUIDString);
        }
    }
}

// 监控接收到数据 - 这是关键！
- (void)peripheral:(CBPeripheral *)peripheral
    didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic
                              error:(NSError *)error {
    %orig;
    
    if (error || !characteristic.value) return;
    
    NSData *data = characteristic.value;
    const uint8_t *bytes = data.bytes;
    NSUInteger length = data.length;
    
    NSString *charUUID = characteristic.UUID.UUIDString;
    NSMutableString *hexStr = [NSMutableString string];
    for (NSUInteger i = 0; i < length; i++) {
        [hexStr appendFormat:@"%02X ", bytes[i]];
    }
    
    NSLog(@"[BJBLE] 📩 收到数据 [%@] 长度:%lu | hex: %@",
        charUUID, (unsigned long)length, hexStr);
    
    // 解析鉴权特征数据
    if ([charUUID isEqualToString:@"2A6F"] || [charUUID isEqualToString:@"2a6f"]) {
        [self handleAuthData:data];
    }
    // 解析控制特征数据
    else if ([charUUID isEqualToString:@"2A7F"] || [charUUID isEqualToString:@"2a7f"]) {
        [self handleControlData:data];
    }
}

// 解析鉴权数据
- (void)handleAuthData:(NSData *)data {
    const uint8_t *bytes = data.bytes;
    NSUInteger length = data.length;
    
    if (length < 49) return;
    
    uint8_t header = bytes[0];
    uint8_t type = bytes[1];
    
    NSLog(@"[BJBLE] 🔐 鉴权数据 - header:0x%02X type:0x%02X", header, type);
    
    BJBLEMonitor *monitor = [BJBLEMonitor shared];
    
    if (type == 0x06) {
        NSLog(@"[BJBLE] 📨 鉴权响应1");
        monitor.bleStatus = BJBleStatusHandshaking1;
    } else if (type == 0x05) {
        NSLog(@"[BJBLE] 📨 鉴权响应2 - 鉴权完成!");
        monitor.bleStatus = BJBleStatusAuthorized;
        monitor.isAuthorized = YES;
    }
}

// 解析控制数据
- (void)handleControlData:(NSData *)data {
    const uint8_t *bytes = data.bytes;
    NSUInteger length = data.length;
    
    if (length < 49) return;
    
    uint8_t type = bytes[1];
    NSLog(@"[BJBLE] 🎮 控制数据 - type:0x%02X", type);
    
    // 尝试从数据中提取信息
    // TODO: 需要逆向加密算法后才能完整解析
}

%end

// ============================================================
// MARK: - FlutterEngine Hook (可选 - 读取 Flutter 层数据)
// ============================================================

// 如果 App 使用 Flutter，可以尝试 hook Flutter 的 MethodChannel
// 但更可靠的方式是直接读取 NSUserDefaults 缓存

// ============================================================
// MARK: - NSUserDefaults Hook - 捕获车辆状态缓存
// ============================================================

%hook NSUserDefaults

- (void)setObject:(id)value forKey:(NSString *)defaultName {
    %orig;
    
    // 监控车辆状态缓存
    if ([defaultName containsString:@"car_status"] || [defaultName containsString:@"carStatus"]) {
        NSLog(@"[BJBLE] 💾 检测到车辆状态更新 key: %@", defaultName);
        
        if ([value isKindOfClass:[NSDictionary class]]) {
            BJCarStatus *status = [[BJCarStatus alloc] init];
            // 复用解析逻辑
            [[BJBLEMonitor shared] readCachedStatus];
        }
    }
}

- (id)objectForKey:(NSString *)defaultName {
    return %orig;
}

%end

// ============================================================
// MARK: - 初始化
// ============================================================

%ctor {
    NSLog(@"[BJBLE] 🚀 宝骏云海 BLE HUD 插件已加载!");
    NSLog(@"[BJBLE] 📱 Bundle ID: %@", [[NSBundle mainBundle] bundleIdentifier]);
    
    // 注册通知监听
    [[NSNotificationCenter defaultCenter] addObserverForName:@"BJBLERefreshHUD"
        object:nil queue:[NSOperationQueue mainQueue]
        usingBlock:^(NSNotification *note) {
        
        BJCarStatus *status = [[BJBLEMonitor shared] readCachedStatus];
        [[HUDViewController shared] updateWithStatus:status];
    }];
}
