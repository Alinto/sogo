# GNUstep makefile

include ../common.make

BUNDLE_NAME = ContactsUI

ContactsUI_PRINCIPAL_CLASS = ContactsUIProduct

ContactsUI_LANGUAGES = BrazilianPortuguese Czech Dutch English French German Italian Spanish Welsh Russian

ContactsUI_OBJC_FILES =			\
	UIxContactsUserFolders.m \
	UIxContactsMailerSelection.m	\
	UIxContactsUserRightsEditor.m	\
	\
	ContactsUIProduct.m		\
	UIxContactsFilterPanel.m	\
	UIxContactView.m		\
	UIxContactEditor.m		\
	UIxListView.m		\
	UIxListEditor.m		\
	UIxContactsListView.m		\
	UIxContactFoldersView.m

ContactsUI_RESOURCE_FILES +=		\
	Version				\
	product.plist			\

ContactsUI_RESOURCE_FILES +=		\
	Toolbars/SOGoContactFolder.toolbar

ContactsUI_LOCALIZED_RESOURCE_FILES +=	\
	Localizable.strings		\

# make

ADDITIONAL_INCLUDE_DIRS += -I../../SOPE/
ADDITIONAL_LIB_DIRS += -L../../SOPE/GDLContentStore/obj/

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
