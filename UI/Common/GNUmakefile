# GNUstep makefile

include ../common.make

BUNDLE_NAME = CommonUI

CommonUI_PRINCIPAL_CLASS = CommonUIProduct

CommonUI_LANGUAGES = Arabic Basque BrazilianPortuguese Catalan ChineseTaiwan Croatian Czech Danish Dutch English Finnish French German Hungarian Icelandic Italian Macedonian NorwegianBokmal NorwegianNynorsk Polish Portuguese Russian Slovak Slovenian SpanishSpain SpanishArgentina Swedish Ukrainian Welsh

CommonUI_OBJC_FILES +=		\
	CommonUIProduct.m	\
	UIxPageFrame.m		\
	\
	UIxAclEditor.m  \
	UIxObjectActions.m	\
	UIxFolderActions.m	\
	UIxParentFolderActions.m \
	UIxUserRightsEditor.m	\
	\
	UIxToolbar.m		\
	\
	WODirectAction+SOGo.m \

CommonUI_RESOURCE_FILES += \
	product.plist


CommonUI_LOCALIZED_RESOURCE_FILES +=	\
	Localizable.strings		\

# make

ADDITIONAL_INCLUDE_DIRS += -I../../SOPE/
ADDITIONAL_LIB_DIRS += -L../../SOPE/GDLContentStore/obj/
ADDITIONAL_LDFLAGS += -Wl,--rpath,$(SOGO_SYSLIBDIR)/sogo

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
