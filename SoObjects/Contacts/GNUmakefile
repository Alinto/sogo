
# GNUstep makefile

include ../common.make

BUNDLE_NAME = Contacts

Contacts_PRINCIPAL_CLASS = SOGoContactsProduct

Contacts_OBJC_FILES =			\
	Product.m			\
	NGVCard+SOGo.m			\
	NGVList+SOGo.m			\
	SOGoFolder+CardDAV.m		\
	SOGoContactFolders.m		\
	SOGoContactGCSEntry.m		\
	SOGoContactGCSList.m		\
	SOGoContactGCSFolder.m		\
	SOGoContactLDIFEntry.m		\
	SOGoContactSourceFolder.m	\
	SOGoUserFolder+Contacts.m	\
	SOGoContactEntryPhoto.m		\
	\
	NSArray+Contacts.m		\
	NSDictionary+LDIF.m		\
	NSString+LDIF.m

Contacts_RESOURCE_FILES +=		\
	product.plist			\

Contacts_LANGUAGES = $(SOGO_LANGUAGES)

Contacts_LOCALIZED_RESOURCE_FILES = Localizable.strings

ADDITIONAL_INCLUDE_DIRS += -I../../SOPE/
ADDITIONAL_LIB_DIRS += -L../../SOPE/GDLContentStore/obj/

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
