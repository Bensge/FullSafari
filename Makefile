DEBUG = 0
ARCHS = armv7 arm64
TARGET = iphone:clang:latest:8.0
GO_EASY_ON_ME = 1

include theos/makefiles/common.mk

TWEAK_NAME = FullSafari
FullSafari_FILES = Tweak.xm

include $(THEOS_MAKE_PATH)/tweak.mk
