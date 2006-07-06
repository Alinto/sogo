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

ContactsUI_RESOURCE_FILES +=		\
	Images/delete.png		\
	Images/new-card.png		\
	Images/new-list.png		\
	Images/properties.png		\
	Images/write.png

ContactsUI_RESOURCE_FILES +=		\
	Toolbars/SOGoContactFolder.toolbar

ContactsUI_LOCALIZED_RESOURCE_FILES +=	\
	Localizable.strings		\

# make

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
include ../../fhsbundle.make
