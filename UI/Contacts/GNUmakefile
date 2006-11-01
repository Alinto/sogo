# GNUstep makefile

include ../common.make

BUNDLE_NAME = ContactsUI

ContactsUI_PRINCIPAL_CLASS = ContactsUIProduct

ContactsUI_LANGUAGES = English French

ContactsUI_OBJC_FILES =			\
	UIxContactsMailerSelection.m	\
	UIxContactsCalendarsSelection.m	\
	UIxContactsAddressBooksSelection.m \
	\
	ContactsUIProduct.m		\
	UIxContactsFilterPanel.m	\
	UIxContactView.m		\
	UIxContactEditor.m		\
	UIxContactsListView.m		\
	UIxContactsListViewContainer.m	\
	UIxContactSelector.m	\
	UIxContactFoldersView.m		\

ContactsUI_RESOURCE_FILES +=		\
	Version				\
	product.plist			\

ContactsUI_RESOURCE_FILES +=		\
	Toolbars/SOGoContactFolder.toolbar

ContactsUI_LOCALIZED_RESOURCE_FILES +=	\
	Localizable.strings		\

# make

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
include ../../fhsbundle.make
