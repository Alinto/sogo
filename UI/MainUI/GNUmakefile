# GNUstep makefile

-include ../common.make

BUNDLE_NAME = MainUI

MainUI_PRINCIPAL_CLASS = MainUIProduct

MainUI_LANGUAGES = English French

MainUI_OBJC_FILES += \
	MainUIProduct.m		\
	SOGoRootPage.m		\
	SOGoUserHomePage.m	\
	SOGoGroupPage.m		\
	SOGoGroupsPage.m	\

MainUI_RESOURCE_FILES += 	\
	Version			\
	product.plist

MainUI_LOCALIZED_RESOURCE_FILES += \
	Locale Localizable.strings

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
include ../../fhsbundle.make
