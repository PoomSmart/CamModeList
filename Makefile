GO_EASY_ON_ME = 1
DEBUG = 0
ARCHS = armv7 arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = CamModeList
CamModeList_FILES = Tweak.xm PSCMLWYPopoverController.m
CamModeList_FRAMEWORKS = CoreGraphics UIKit

include $(THEOS_MAKE_PATH)/tweak.mk

internal-stage::
	##$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	##$(ECHO_NOTHING)cp -R CamModeList $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)find $(THEOS_STAGING_DIR) -name .DS_Store | xargs rm -rf$(ECHO_END)
