export THEOS=/opt/theos
export DEBUG=0
export RELEASE=1

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = FullSafari
FullSafari_FILES = Tweak.xm

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 MobileSafari"
