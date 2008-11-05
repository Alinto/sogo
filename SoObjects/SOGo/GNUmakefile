# GNUstep makefile

include ../../config.make
include $(GNUSTEP_MAKEFILES)/common.make
-include ../../Version
-include ./Version

FRAMEWORK_NAME = SOGo

SOGo_INSTALL_DIR = $(SOGO_LIBDIR)

TOOL_NAME = \
# 	sogo_email2uid	\
# 	sogo_shares4uid	\
# 	sogo_emails4uid	\
# 	sogo_defaults

SOGo_VERSION=$(MAJOR_VERSION).$(MINOR_VERSION)

#	SOGoCustomGroupFolder.h		\
# 	SOGoGroupsFolder.h		\
# 	SOGoGroupFolder.h		
SOGo_HEADER_FILES = \
	SOGoCache.h			\
	SOGoObject.h			\
	SOGoContentObject.h		\
	SOGoFolder.h			\
	SOGoParentFolder.h		\
	SOGoUserFolder.h		\
	\
	LDAPUserManager.h		\
	LDAPSource.h			\
	SOGoDateFormatter.h		\
	SOGoPermissions.h		\
	iCalEntityObject+Utilities.h	\
	NSArray+DAV.h			\
	NSArray+Utilities.h		\
	NSCalendarDate+SOGo.h		\
	NSDictionary+DAV.h		\
	NSDictionary+URL.h		\
	NSDictionary+Utilities.h	\
	NSNull+Utilities.h		\
	NSNumber+Utilities.h		\
	NSObject+DAV.h			\
	NSObject+Utilities.h		\
	NSString+DAV.h			\
	NSString+Utilities.h		\
	NSURL+DAV.h			\
	\
	SOGoDAVAuthenticator.h		\
	SOGoWebAuthenticator.h		\
	SOGoWebDAVAclManager.h		\
	SOGoWebDAVValue.h		\
	SOGoMailer.h			\
	SOGoUser.h			\
	SOGoUserManager.h		\
	\
	NSDictionary+BSJSONAdditions.h	\
	NSScanner+BSJSONAdditions.h	\
	\
	WORequest+SOGo.h		\
	WOContext+SOGo.h

#	SOGoCustomGroupFolder.m		\
# 	SOGoGroupsFolder.m		\
# 	SOGoGroupFolder.m		
SOGo_OBJC_FILES = \
	SOGoCache.m			\
	SOGoObject.m			\
	SOGoContentObject.m		\
	SOGoFolder.m			\
	SOGoGCSFolder.m			\
	SOGoParentFolder.m		\
	SOGoUserFolder.m		\
	\
	SOGoDateFormatter.m		\
	SOGoPermissions.m		\
	LDAPUserManager.m		\
	LDAPSource.m			\
	SOGoUserDefaults.m		\
	iCalEntityObject+Utilities.m	\
	NSArray+DAV.m			\
	NSArray+Utilities.m		\
	NSCalendarDate+SOGo.m		\
	NSDictionary+DAV.m		\
	NSDictionary+URL.m		\
	NSDictionary+Utilities.m	\
	NSNull+Utilities.m		\
	NSNumber+Utilities.m		\
	NSObject+DAV.m			\
	NSObject+Utilities.m		\
	NSString+DAV.m  		\
	NSString+Utilities.m		\
	NSURL+DAV.m	  		\
	\
	SOGoDAVAuthenticator.m		\
	SOGoWebAuthenticator.m		\
	SOGoWebDAVAclManager.m		\
	SOGoWebDAVValue.m		\
	SOGoMailer.m			\
	SOGoUser.m			\
	SOGoUserManager.m		\
	\
	NSDictionary+BSJSONAdditions.m	\
	NSScanner+BSJSONAdditions.m	\
	\
	WORequest+SOGo.m		\
	WOContext+SOGo.m

SOGo_RESOURCE_FILES = \
	DAVReportMap.plist

ifeq ($(ldap_config),yes)
SOGo_OBJC_FILES += SOGoLDAPUserDefaults.m
SOGo_HEADER_FILES += SOGoLDAPUserDefaults.h
endif

# tools

sogo_email2uid_OBJC_FILES  += sogo_email2uid.m
sogo_shares4uid_OBJC_FILES += sogo_shares4uid.m
sogo_emails4uid_OBJC_FILES += sogo_emails4uid.m
sogo_defaults_OBJC_FILES   += sogo_defaults.m

ADDITIONAL_TOOL_LIBS += -Lobj -lSOGo$(LIBRARY_NAME_SUFFIX)
ADDITIONAL_INCLUDE_DIRS += -I../../SOPE/
ADDITIONAL_LIB_DIRS += -L../../SOPE/GDLContentStore/obj/

-include GNUmakefile.preamble
ifneq ($(FHS_INSTALL_ROOT),)
GNUSTEP_HEADERS=$(DESTDIR)$(FHS_INSTALL_ROOT)/include
endif
include $(GNUSTEP_MAKEFILES)/framework.make
include $(GNUSTEP_MAKEFILES)/tool.make
-include GNUmakefile.postamble
