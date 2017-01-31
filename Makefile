DEBUG = 0
TARGET = iphone:clang:latest:8.0
GO_EASY_ON_ME = 1
PACKAGE_VERSION = 1.0.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = FullSafari
FullSafari_FILES = Tweak.xm

include $(THEOS_MAKE_PATH)/tweak.mk
