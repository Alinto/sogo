# GNUstep makefile

include ../common.make

BUNDLE_NAME = PreferencesUI

PreferencesUI_PRINCIPAL_CLASS = PreferencesUIProduct

PreferencesUI_LANGUAGES = Arabic BrazilianPortuguese Catalan Czech Danish Dutch English Finnish French German Hungarian Icelandic Italian NorwegianBokmal NorwegianNynorsk Polish Russian Slovak SpanishSpain SpanishArgentina Swedish Ukrainian Welsh

PreferencesUI_OBJC_FILES =		\
	PreferencesUIProduct.m		\
	\
	UIxJSONPreferences.m		\
	UIxPreferences.m		\
	UIxFilterEditor.m		\
	\
	UIxAdditionalPreferences.m

PreferencesUI_RESOURCE_FILES += \
	product.plist	

PreferencesUI_RESOURCE_FILES += \
	Toolbars/UIxPreferences.toolbar

PreferencesUI_LOCALIZED_RESOURCE_FILES += \
	Localizable.strings		\

ADDITIONAL_INCLUDE_DIRS += -I../../SOPE/
ADDITIONAL_LIB_DIRS += -L../../SOPE/GDLContentStore/obj/
ADDITIONAL_LDFLAGS += -Wl,--rpath,$(SOGO_SYSLIBDIR)/sogo

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
