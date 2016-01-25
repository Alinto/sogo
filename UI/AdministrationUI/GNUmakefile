# GNUstep makefile

include ../common.make

BUNDLE_NAME = AdministrationUI

AdministrationUI_PRINCIPAL_CLASS = AdministrationUIProduct

AdministrationUI_LANGUAGES = Arabic Basque BrazilianPortuguese Catalan ChineseTaiwan Croatian Czech Danish Dutch English Finnish French German Hungarian Italian Macedonian NorwegianBokmal NorwegianNynorsk Polish Portuguese Russian Slovak Slovenian SpanishSpain SpanishArgentina Swedish Ukrainian Welsh

AdministrationUI_OBJC_FILES =		\
	AdministrationUIProduct.m	\
	\
	UIxAdministration.m		\
	UIxAdministrationFilterPanel.m

AdministrationUI_RESOURCE_FILES += \
	product.plist	

AdministrationUI_RESOURCE_FILES += \
	Toolbars/UIxAdministration.toolbar

AdministrationUI_LOCALIZED_RESOURCE_FILES += \
	Localizable.strings		\

ADDITIONAL_INCLUDE_DIRS += -I../../SOPE/
ADDITIONAL_LIB_DIRS += -L../../SOPE/GDLContentStore/obj/
ADDITIONAL_LDFLAGS += -Wl,--rpath,$(SOGO_SYSLIBDIR)/sogo

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
