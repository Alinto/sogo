# GNUstep makefile

include ../common.make

BUNDLE_NAME = Contacts

Contacts_PRINCIPAL_CLASS = SOGoContactsProduct

Contacts_OBJC_FILES =			\
	Product.m			\
					\
	SOGoContactFolders.m		\
	SOGoContactGCSEntry.m		\
	SOGoContactGCSFolder.m		\
	SOGoContactLDIFEntry.m		\
	SOGoContactLDAPFolder.m		\

Contacts_RESOURCE_FILES +=		\
	Version				\
	product.plist			\

ADDITIONAL_INCLUDE_DIRS += -I../../SOPE/sope-gdl1/
ADDITIONAL_LIB_DIRS += -L../../SOPE/sope-gdl1/GDLContentStore/obj/

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
include ../../fhsbundle.make
