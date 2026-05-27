ARCHS = arm64
TARGET := iphone:clang:16.5:14.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = BaojunBLEHUD

BaojunBLEHUD_FILES = Tweak.xm HUDViewController.xm BLEMonitor.xm
BaojunBLEHUD_CFLAGS = -fobjc-arc -Wno-unused-variable
BaojunBLEHUD_FRAMEWORKS = UIKit CoreBluetooth QuartzCore Foundation
BaojunBLEHUD_PRIVATE_FRAMEWORKS = BackBoardServices

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 com.baojun.plus" || true
