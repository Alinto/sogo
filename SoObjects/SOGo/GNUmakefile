# GNUstep makefile

include ../../config.make
include $(GNUSTEP_MAKEFILES)/common.make
include ../../Version

FRAMEWORK_NAME = SOGo

SOGo_VERSION=$(MAJOR_VERSION).$(MINOR_VERSION).$(SUBMINOR_VERSION)

#SOGo_INSTALL_DIR = $(SOGO_LIBDIR)
SOGo_INSTALL_DIR = $(DESTDIR)$(GNUSTEP_$(GNUSTEP_INSTALLATION_DOMAIN)_FRAMEWORKS)

ADDITIONAL_LDFLAGS += -Wl,--rpath,$(SOGO_SYSLIBDIR)/sogo

SOGo_HEADER_FILES = \
	SOGoBuild.h \
	SOGoProductLoader.h		\
	\
	BSONCodec.h			\
	EOBitmaskQualifier.h 		\
	EOQualifier+SOGoCacheObject.h 	\
	GCSSpecialQueries+SOGoCacheObject.h \
	SOGoCache.h			\
	SOGoCacheGCSFolder.h		\
	SOGoCacheGCSObject.h		\
	SOGoCacheObject.h		\
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
	NSString+Crypto.h		\
	NSData+Crypto.h			\
	NSURL+DAV.h			\
	\
	SOGoAuthenticator.h		\
	SOGoSession.h			\
	SOGoCASSession.h		\
	SOGoDAVAuthenticator.h		\
	SOGoProxyAuthenticator.h	\
	SOGoStaticAuthenticator.h	\
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
	WOContext+SOGo.h		\
	\
	SOGoCredentialsFile.h

all::
	@touch SOGoBuild.m

SOGo_OBJC_FILES = \
	SOGoBuild.m \
	SOGoProductLoader.m		\
	\
	BSONCodec.m			\
	EOBitmaskQualifier.m		\
	EOQualifier+SOGoCacheObject.m	\
	GCSSpecialQueries+SOGoCacheObject.m \
	SOGoCache.m			\
	SOGoCacheGCSFolder.m		\
	SOGoCacheGCSObject.m		\
	SOGoCacheObject.m		\
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
	NSString+Crypto.m		\
	NSData+Crypto.m			\
	NSURL+DAV.m	  		\
	\
	SOGoSession.m			\
	SOGoCASSession.m		\
	SOGoDAVAuthenticator.m		\
	SOGoProxyAuthenticator.m	\
	SOGoStaticAuthenticator.m	\
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
	WOContext+SOGo.m		\
	\
	SOGoCredentialsFile.m

SOGo_C_FILES = lmhash.c

SOGo_RESOURCE_FILES = \
	SOGoDefaults.plist \
	DAVReportMap.plist \
	CASLogoutRequestMap.plist

ifeq ($(saml2_config), yes)
	SOGo_HEADER_FILES += SOGoSAML2Session.h SOGoSAML2Exceptions.h
	SOGo_OBJC_FILES += SOGoSAML2Session.m SOGoSAML2Exceptions.m
	SOGo_RESOURCE_FILES += SOGoSAML2Metadata.xml

SOGoSAML2Exceptions.h SOGoSAML2Exceptions.m: gen-saml2-exceptions.py
	$(ECHO_CREATING) ./gen-saml2-exceptions.py $(LASSO_CFLAGS) $(END_ECHO)

distclean clean::
	-rm -f SOGoSAML2Exceptions.h SOGoSAML2Exceptions.m

endif

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
GNUSTEP_TARGET_LDIR=sogo
include $(GNUSTEP_MAKEFILES)/framework.make
include $(GNUSTEP_MAKEFILES)/library.make
include $(GNUSTEP_MAKEFILES)/tool.make
-include GNUmakefile.postamble
