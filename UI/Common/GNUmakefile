# GNUstep makefile

include ../common.make

BUNDLE_NAME = CommonUI

CommonUI_PRINCIPAL_CLASS = CommonUIProduct

CommonUI_LANGUAGES = BrazilianPortuguese Czech Dutch English French German Italian Spanish Welsh Russian

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
	Version			\
	product.plist		\
	Toolbars/SOGoAclOwner.toolbar \
	Toolbars/SOGoAclAssistant.toolbar \


CommonUI_LOCALIZED_RESOURCE_FILES +=	\
	Localizable.strings		\

# make

ADDITIONAL_INCLUDE_DIRS += -I../../SOPE/
ADDITIONAL_LIB_DIRS += -L../../SOPE/GDLContentStore/obj/

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
