# GNUstep makefile

include ../../config.make
include $(GNUSTEP_MAKEFILES)/common.make
include ../../Version

FRAMEWORK_NAME = SOGo

#SOGo_INSTALL_DIR = $(SOGO_LIBDIR)
SOGo_INSTALL_DIR = $(DESTDIR)$(GNUSTEP_$(GNUSTEP_INSTALLATION_DOMAIN)_FRAMEWORKS)

SOGo_VERSION=$(MAJOR_VERSION).$(MINOR_VERSION).$(SUBMINOR_VERSION)

SOGo_HEADER_FILES = \
	SOGoBuild.h \
	SOGoProductLoader.h		\
	\
	SOGoCache.h			\
	SOGoConstants.h			\
	SOGoObject.h			\
	SOGoContentObject.h		\
	SOGoFolder.h			\
	SOGoGCSFolder.h			\
	SOGoParentFolder.h		\
	SOGoUserFolder.h		\
	\
	SOGoSieveManager.h		\
	\
	SOGoUserManager.h		\
	LDAPSource.h			\
	LDAPSourceSchema.h		\
	SQLSource.h			\
	SOGoUserProfile.h		\
	SOGoDateFormatter.h		\
	SOGoPermissions.h		\
	SOGoStartupLogger.h		\
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
	SOGoAuthenticator.h		\
	SOGoSession.h			\
	SOGoCASSession.h		\
	SOGoDAVAuthenticator.h		\
	SOGoProxyAuthenticator.h	\
	SOGoWebAuthenticator.h		\
	SOGoWebDAVAclManager.h		\
	SOGoWebDAVValue.h		\
	SOGoMailer.h			\
	SOGoGroup.h			\
	SOGoUser.h			\
	\
	DOMNode+SOGo.h			\
	\
	WORequest+SOGo.h		\
	WOResourceManager+SOGo.h	\
	WOResponse+SOGo.h		\
	WOContext+SOGo.h

# daemon tool
all::
	@touch SOGoBuild.m

SOGo_OBJC_FILES = \
	SOGoBuild.m \
	SOGoProductLoader.m		\
	\
	SOGoCache.m			\
	SOGoConstants.m			\
	SOGoObject.m			\
	SOGoContentObject.m		\
	SOGoFolder.m			\
	SOGoGCSFolder.m			\
	SOGoParentFolder.m		\
	SOGoPublicBaseFolder.m		\
	SOGoUserFolder.m		\
	\
	SOGoSieveManager.m		\
	\
	SOGoDefaultsSource.m		\
	SOGoSystemDefaults.m		\
	SOGoDomainDefaults.m		\
	SOGoUserDefaults.m		\
	SOGoUserSettings.m		\
	\
	SOGoDateFormatter.m		\
	SOGoPermissions.m		\
	SOGoStartupLogger.m		\
	SOGoUserManager.m		\
	LDAPSource.m			\
	LDAPSourceSchema.m		\
	SQLSource.m			\
	SOGoUserProfile.m		\
	SOGoSQLUserProfile.m		\
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
	SOGoSession.m			\
	SOGoCASSession.m		\
	SOGoDAVAuthenticator.m		\
	SOGoProxyAuthenticator.m	\
	SOGoWebAuthenticator.m		\
	SOGoWebDAVAclManager.m		\
	SOGoWebDAVValue.m		\
	SOGoMailer.m			\
	SOGoGroup.m			\
	SOGoUser.m			\
	\
	DOMNode+SOGo.m			\
	\
	WORequest+SOGo.m		\
	WOResourceManager+SOGo.m	\
	WOResponse+SOGo.m		\
	WOContext+SOGo.m

SOGo_RESOURCE_FILES = \
	SOGoDefaults.plist \
	DAVReportMap.plist

ifeq ($(ldap_config),yes)

LIBRARY_NAME += \
	SOGoNSUserDefaults

SOGoNSUserDefaults_VERSION = 1
SOGoNSUserDefaults_INSTALL_DIR = $(SOGO_LIBDIR)

SOGoNSUserDefaults_OBJC_FILES = \
	SOGoLDAPUserDefaultsBootstrap.m \
	SOGoLDAPUserDefaults.m

endif

ADDITIONAL_TOOL_LIBS += -Lobj -lSOGo$(LIBRARY_NAME_SUFFIX)
ADDITIONAL_INCLUDE_DIRS += -I../../SOPE/
ADDITIONAL_LIB_DIRS += -L../../SOPE/GDLContentStore/obj/
ADDITIONAL_LDFLAGS += -lmemcached

-include GNUmakefile.preamble
ifneq ($(FHS_INSTALL_ROOT),)
GNUSTEP_HEADERS=$(DESTDIR)$(FHS_INSTALL_ROOT)/include
endif
include $(GNUSTEP_MAKEFILES)/framework.make
include $(GNUSTEP_MAKEFILES)/library.make
include $(GNUSTEP_MAKEFILES)/tool.make
-include GNUmakefile.postamble
