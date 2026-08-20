TARGET := iphone:latest:15.8
ARCHS := arm64

THEOS ?= $(HOME)/theos
SDKROOT ?= $(THEOS)/sdks/iPhoneOS16.5.sdk
FINALPACKAGE ?= 0

.PHONY: clean package

clean:
	@rm -rf .wolfox-build WolFox.dylib

package:
	@THEOS="$(THEOS)" SDKROOT="$(SDKROOT)" MIN_IOS=15.8 REQUIRED_SDK_VERSION=16.5 WOLFOX_ARCHS=arm64 WOLFOX_REQUIRE_SIGNING=1 WOLFOX_HARDENING=1 ./build_v1_deb.sh
