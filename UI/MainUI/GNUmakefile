# GNUstep makefile

include ../common.make

BUNDLE_NAME = MainUI

MainUI_PRINCIPAL_CLASS = MainUIProduct

MainUI_LANGUAGES = BrazilianPortuguese Catalan Czech Danish Dutch English French German Hungarian Icelandic Italian NorwegianBokmal NorwegianNynorsk Polish Russian SpanishSpain SpanishArgentina Swedish Ukrainian Welsh

MainUI_OBJC_FILES += \
	MainUIProduct.m		\
	SOGoRootPage.m		\
	SOGoUserHomePage.m	\
	SOGoBrowsersPanel.m	\
	UIxLoading.m		\

MainUI_RESOURCE_FILES += 	\
	product.plist		\
	SOGoProfile.sql \
	SOGoProfile-oracle.sql \
	OCSFolderInfo.sql \
	OCSFolderInfo-oracle.sql \

MainUI_LOCALIZED_RESOURCE_FILES += \
	Locale Localizable.strings

ADDITIONAL_INCLUDE_DIRS += -I../../SOPE/
ADDITIONAL_LIB_DIRS += -L../../SOPE/GDLContentStore/obj/

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
