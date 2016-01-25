# GNUstep makefile

include ../common.make

BUNDLE_NAME = ContactsUI

ContactsUI_PRINCIPAL_CLASS = ContactsUIProduct

ContactsUI_LANGUAGES = Arabic Basque BrazilianPortuguese Catalan ChineseTaiwan Croatian Czech Danish Dutch English Finnish French German Hungarian Icelandic Italian Macedonian NorwegianBokmal NorwegianNynorsk Polish Portuguese Russian Slovak Slovenian SpanishSpain SpanishArgentina Swedish Ukrainian Welsh

ContactsUI_OBJC_FILES =			\
	UIxContactsUserFolders.m	\
	UIxContactsMailerSelection.m	\
	UIxContactsUserRightsEditor.m	\
	\
	ContactsUIProduct.m		\
	UIxContactsFilterPanel.m	\
	UIxContactActions.m		\
	UIxContactView.m		\
	UIxContactEditor.m		\
	UIxListView.m			\
	UIxListEditor.m			\
	UIxContactsListActions.m	\
	UIxContactFoldersView.m		\
	UIxContactFolderActions.m       \
	UIxContactFolderLinksTemplate.m \
	UIxContactFolderProperties.m

ContactsUI_RESOURCE_FILES +=		\
	product.plist			\

ContactsUI_RESOURCE_FILES +=		\
	Toolbars/SOGoContactFolder.toolbar

ContactsUI_LOCALIZED_RESOURCE_FILES +=	\
	Localizable.strings		\

# make

ADDITIONAL_INCLUDE_DIRS += -I../../SOPE/
ADDITIONAL_LIB_DIRS += -L../../SOPE/GDLContentStore/obj/
ADDITIONAL_LDFLAGS += -Wl,--rpath,$(SOGO_SYSLIBDIR)/sogo

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
