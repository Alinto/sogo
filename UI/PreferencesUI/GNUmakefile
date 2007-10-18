# GNUstep makefile

include ../common.make

BUNDLE_NAME = PreferencesUI

PreferencesUI_PRINCIPAL_CLASS = PreferencesUIProduct

PreferencesUI_LANGUAGES = English French German

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

ADDITIONAL_INCLUDE_DIRS += -I../../SOPE/sope-gdl1/
ADDITIONAL_LIB_DIRS += -L../../SOPE/sope-gdl1/GDLContentStore/obj/

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
include ../../fhsbundle.make


