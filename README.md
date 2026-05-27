# 宝骏云海 BLE 车辆状态悬浮窗 v0.1

## 🚗 功能

- 实时显示车辆状态（电量、续航、车门、空调、温度等）
- 浮动 HUD 悬浮窗，可拖拽、可展开
- 监控 BLE 连接状态
- 支持 Dopamine RootHide 越狱

## 📱 车辆信息

| 项目 | 值 |
|------|------|
| 车型 | 宝骏云海 140km 插混版 (PHEV) |
| VIN | LK6ADAH92RB765125 |
| BLE MAC | CC:45:A5:DA:B5:C3 |
| 设备名 | E260-BLE |

## 📡 BLE 协议

```
Service 0x181a (鉴权):
  Char 0x2a6e (Write) - 鉴权写入
  Char 0x2a6f (Read/Notify) - 鉴权读取

Service 0x182a (控制):
  Char 0x2a7e (Write) - 控制写入
  Char 0x2a7f (Read/Notify) - 控制读取
```

## 🔧 安装

### 方法 1: 通过 GitHub Actions 构建
1. Fork 此仓库
2. 推送代码触发 Actions
3. 下载 `.deb` artifact
4. 通过 Filza 安装

### 方法 2: 本地构建
```bash
# 需要安装 Theos
export THEOS=~/theos
make clean package THEOS_PACKAGE_SCHEME=rootless
```

## 📂 项目结构

```
baojun_ble_hud/
├── control                    # Debian 包信息
├── Makefile                   # 构建配置
├── baojun_ble_hud.plist       # App 过滤器
├── Tweak.xm                   # 主 Hook 文件
├── BLEMonitor.h               # BLE 监控头文件
├── BLEMonitor.m               # BLE 监控实现
├── HUDViewController.h        # 悬浮窗头文件
├── HUDViewController.m        # 悬浮窗实现
└── .github/workflows/
    └── build.yml              # CI 构建
```

## 🔑 BLE 密钥

| 项目 | 值 |
|------|------|
| 主密钥 | CED6CA88AF34726F43486E6D0040FB78 |
| 主随机数 | 627E346190C934150CBF795897A47FA2 |
| 钥匙类型 | owner |
| 有效期至 | 2038-01-01 |

## ⚠️ 待完成

- [ ] 逆向 BLE 加密协议 (AES-128)
- [ ] 实现完整的鉴权握手
- [ ] 解析控制特征数据
- [ ] 支持主动车控命令（解锁/闭锁/空调）
