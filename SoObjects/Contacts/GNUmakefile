
# GNUstep makefile

include ../common.make

BUNDLE_NAME = Contacts

Contacts_PRINCIPAL_CLASS = SOGoContactsProduct

Contacts_OBJC_FILES =			\
	Product.m			\
	SOGoFolder+CardDAV.m		\
	SOGoContactFolders.m		\
	SOGoContactGCSEntry.m		\
	SOGoContactGCSFolder.m		\
	SOGoContactLDIFEntry.m		\
	SOGoContactLDAPFolder.m		\

Contacts_RESOURCE_FILES +=		\
	Version				\
	product.plist			\

ADDITIONAL_INCLUDE_DIRS += -I../../SOPE/
ADDITIONAL_LIB_DIRS += -L../../SOPE/GDLContentStore/obj/

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
