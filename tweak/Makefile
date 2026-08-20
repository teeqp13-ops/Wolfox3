TARGET := iphone:clang:latest:14.0
ARCHS := arm64 arm64e
INSTALL_TARGET_PROCESSES := YouTube

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := DLTube
DLTube_FILES := Tweak.xm
DLTube_CFLAGS := -fobjc-arc
DLTube_FRAMEWORKS := Foundation UIKit AVFoundation AVKit

include $(THEOS_MAKE_PATH)/tweak.mk
