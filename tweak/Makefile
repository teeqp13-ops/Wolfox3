TARGET := iphone:clang:latest:14.0
ARCHS := arm64 arm64e
INSTALL_TARGET_PROCESSES := YouTube

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := WolfTube
WolfTube_FILES := Tweak.xm
WolfTube_CFLAGS := -fobjc-arc
WolfTube_FRAMEWORKS := Foundation UIKit AVFoundation AVKit

include $(THEOS_MAKE_PATH)/tweak.mk
