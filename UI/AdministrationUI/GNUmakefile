# GNUstep makefile

include ../common.make

BUNDLE_NAME = AdministrationUI

AdministrationUI_PRINCIPAL_CLASS = AdministrationUIProduct

AdministrationUI_LANGUAGES = BrazilianPortuguese Czech Dutch English French German Hungarian Italian Spanish Welsh Russian

AdministrationUI_OBJC_FILES =		\
	AdministrationUIProduct.m	\
	\
	UIxAdministration.m		\
	UIxAdministrationFilterPanel.m

AdministrationUI_RESOURCE_FILES += \
	Version		\
	product.plist	

#AdministrationUI_RESOURCE_FILES += \
#	Toolbars/UIxAdministration.toolbar

AdministrationUI_LOCALIZED_RESOURCE_FILES += \
	Localizable.strings		\

ADDITIONAL_INCLUDE_DIRS += -I../../SOPE/
ADDITIONAL_LIB_DIRS += -L../../SOPE/GDLContentStore/obj/

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
