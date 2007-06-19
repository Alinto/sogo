# GNUstep makefile

include ../common.make

BUNDLE_NAME = PreferencesUI

PreferencesUI_PRINCIPAL_CLASS = PreferencesUIProduct

PreferencesUI_LANGUAGES = English French

PreferencesUI_OBJC_FILES =		\
	PreferencesUIProduct.m		\
	\
	UIxJSONPreferences.m		\
	UIxPreferences.m

PreferencesUI_RESOURCE_FILES += \
	Version		\
	product.plist	

PreferencesUI_RESOURCE_FILES += \
	Toolbars/UIxPreferences.toolbar

PreferencesUI_LOCALIZED_RESOURCE_FILES += \
	Localizable.strings		\

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
include ../../fhsbundle.make


