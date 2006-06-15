# GNUstep makefile

include ../common.make

BUNDLE_NAME = ContactsUI

ContactsUI_PRINCIPAL_CLASS = ContactsUIProduct

ContactsUI_LANGUAGES = English French

ContactsUI_OBJC_FILES =			\
	UIxContactsListViewBase.m	\
	UIxContactEditorBase.m		\
	\
	ContactsUIProduct.m		\
	UIxContactsSelectionView.m	\
	UIxContactView.m		\
	UIxContactSelector.m		\
	UIxContactEditor.m		\
	UIxContactsListView.m		\

ContactsUI_RESOURCE_FILES +=		\
	Version				\
	product.plist			\

ContactsUI_LOCALIZED_RESOURCE_FILES +=	\
	Localizable.strings		\

# make

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
include ../../fhsbundle.make
