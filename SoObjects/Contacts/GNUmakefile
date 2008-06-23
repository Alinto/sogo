
# GNUstep makefile

include ../common.make

BUNDLE_NAME = Contacts

Contacts_PRINCIPAL_CLASS = SOGoContactsProduct

Contacts_OBJC_FILES =			\
	Product.m			\
	SOGoFolder+CardDAV.m		\
	SOGoContactFolders.m		\
	SOGoContactGCSEntry.m		\
	SOGoContactGCSList.m		\
	SOGoContactGCSFolder.m		\
	SOGoContactLDIFEntry.m		\
	SOGoContactLDAPFolder.m		\

Contacts_RESOURCE_FILES +=		\
	Version				\
	product.plist			\

Contacts_LANGUAGES = Dutch English French German Italian Spanish

Contacts_LOCALIZED_RESOURCE_FILES = Localizable.strings

ADDITIONAL_INCLUDE_DIRS += -I../../SOPE/
ADDITIONAL_LIB_DIRS += -L../../SOPE/GDLContentStore/obj/

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
