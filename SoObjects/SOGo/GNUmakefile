# GNUstep makefile

-include ../../config.make
include $(GNUSTEP_MAKEFILES)/common.make
-include ../../Version
-include ./Version

LIBRARY_NAME = libSOGo

TOOL_NAME = \
# 	agenor_email2uid	\
# 	agenor_shares4uid	\
# 	agenor_emails4uid	\
# 	agenor_defaults

libSOGo_SOVERSION=$(MAJOR_VERSION).$(MINOR_VERSION)

libSOGo_HEADER_FILES_DIR         = .
libSOGo_HEADER_FILES_INSTALL_DIR = /SOGo
FHS_HEADER_DIRS = SOGo

libSOGo_HEADER_FILES = \
	SOGoObject.h			\
	SOGoContentObject.h		\
	SOGoFolder.h			\
	SOGoParentFolder.h		\
	SOGoUserFolder.h		\
	SOGoGroupsFolder.h		\
	SOGoGroupFolder.h		\
	SOGoCustomGroupFolder.h		\
	\
	LDAPUserManager.h		\
	LDAPSource.h			\
	SOGoDateFormatter.h		\
	SOGoPermissions.h		\
	SOGoDAVRendererTypes.h		\
	NSArray+Utilities.h		\
	NSDictionary+URL.h		\
	NSDictionary+Utilities.h	\
	NSObject+Utilities.h		\
	NSString+Utilities.h		\
	NSNumber+Utilities.h		\
	NSNull+Utilities.h		\
	NSDictionary+URL.h		\
	NSCalendarDate+SOGo.h		\
	\
	SOGoDAVAuthenticator.h		\
	SOGoWebAuthenticator.h		\
	SOGoMailer.h			\
	SOGoUser.h			\

libSOGo_OBJC_FILES = \
	SOGoObject.m			\
	SOGoContentObject.m		\
	SOGoFolder.m			\
	SOGoParentFolder.m		\
	SOGoUserFolder.m		\
	SOGoGroupsFolder.m		\
	SOGoGroupFolder.m		\
	SOGoCustomGroupFolder.m		\
	\
	SOGoDateFormatter.m		\
	SOGoPermissions.m		\
	LDAPUserManager.m		\
	LDAPSource.m			\
	SOGoDAVRendererTypes.m		\
	AgenorUserDefaults.m		\
	NSArray+Utilities.m		\
	NSDictionary+URL.m		\
	NSDictionary+Utilities.m	\
	NSObject+Utilities.m		\
	NSString+Utilities.m		\
	NSNumber+Utilities.m		\
	NSNull+Utilities.m		\
	NSCalendarDate+SOGo.m		\
	\
	SOGoDAVAuthenticator.m		\
	SOGoWebAuthenticator.m		\
	SOGoMailer.m			\
	SOGoUser.m			\

# tools

agenor_email2uid_OBJC_FILES  += agenor_email2uid.m
agenor_shares4uid_OBJC_FILES += agenor_shares4uid.m
agenor_emails4uid_OBJC_FILES += agenor_emails4uid.m
agenor_defaults_OBJC_FILES   += agenor_defaults.m

ADDITIONAL_TOOL_LIBS += -Lobj -lSOGo$(LIBRARY_NAME_SUFFIX)
ADDITIONAL_INCLUDE_DIRS += -I../../SOPE/
ADDITIONAL_LIB_DIRS += -L../../SOPE/GDLContentStore/obj/

-include GNUmakefile.preamble
include ../common.make
include $(GNUSTEP_MAKEFILES)/library.make
include $(GNUSTEP_MAKEFILES)/tool.make
-include GNUmakefile.postamble
-include ../../fhslib.make
-include ../../fhstools.make
