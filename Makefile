TARGET = iphone:clang:latest:8.0
DEBUG = 1
PACKAGE_VERSION = 1.3.1

INSTALL_TARGET_PROCESSES = MobileSafari

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = FullSafari
FullSafari_FILES = Tweak.xm

include $(THEOS_MAKE_PATH)/tweak.mk
