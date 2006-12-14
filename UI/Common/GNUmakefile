# GNUstep makefile

include ../common.make

BUNDLE_NAME = CommonUI

CommonUI_PRINCIPAL_CLASS = CommonUIProduct

CommonUI_LANGUAGES = English French

CommonUI_OBJC_FILES +=		\
	CommonUIProduct.m	\
	UIxPageFrame.m		\
	UIxPrintPageFrame.m	\
	UIxSortButton.m		\
	UIxAppNavView.m		\
	UIxJSClose.m		\
	\
	UIxAclEditor.m  \
	UIxElemBuilder.m	\
	UIxTabView.m		\
	UIxTabItem.m		\
	\
	UIxSortableTableHeader.m \
	\
	UIxToolbar.m

CommonUI_RESOURCE_FILES += \
	Version			\
	product.plist		\
	Toolbars/SOGoAclOwner.toolbar \
	Toolbars/SOGoAclAssistant.toolbar \


CommonUI_LOCALIZED_RESOURCE_FILES +=	\
	Localizable.strings		\

# make

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
include ../../fhsbundle.make
