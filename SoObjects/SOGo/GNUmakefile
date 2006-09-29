# GNUstep makefile

-include ../../config.make
include $(GNUSTEP_MAKEFILES)/common.make
-include ../../Version
-include ./Version

LIBRARY_NAME = libSOGo

TOOL_NAME = \
	agenor_email2uid	\
	agenor_shares4uid	\
	agenor_emails4uid	\
	agenor_defaults

libSOGo_SOVERSION=$(MAJOR_VERSION).$(MINOR_VERSION)

libSOGo_HEADER_FILES_DIR         = .
libSOGo_HEADER_FILES_INSTALL_DIR = /SOGo
FHS_HEADER_DIRS = SOGo

libSOGo_HEADER_FILES = \
	SOGoObject.h			\
	SOGoFolder.h			\
	SOGoContentObject.h		\
	SOGoUserFolder.h		\
	SOGoGroupsFolder.h		\
	SOGoGroupFolder.h		\
	SOGoCustomGroupFolder.h		\
	\
	AgenorUserManager.h		\
	SOGoLRUCache.h			\
	NSString+iCal.h			\
	NSObject+AptComparison.h	\
	WOContext+Agenor.h		\
	\
	SOGoAuthenticator.h		\
	SOGoUser.h			\

libSOGo_OBJC_FILES = \
	SOGoObject.m			\
	SOGoFolder.m			\
	SOGoContentObject.m		\
	SOGoUserFolder.m		\
	SOGoGroupsFolder.m		\
	SOGoGroupFolder.m		\
	SOGoCustomGroupFolder.m		\
	\
	SOGoLRUCache.m			\
	AgenorUserManager.m		\
	NSObject+AptComparison.m	\
	WOContext+Agenor.m		\
	AgenorUserDefaults.m		\
	\
	SOGoAuthenticator.m		\
	SOGoUser.m			\

# tools

agenor_email2uid_OBJC_FILES  += agenor_email2uid.m
agenor_shares4uid_OBJC_FILES += agenor_shares4uid.m
agenor_emails4uid_OBJC_FILES += agenor_emails4uid.m
agenor_defaults_OBJC_FILES   += agenor_defaults.m

ADDITIONAL_TOOL_LIBS += -Lshared_debug_obj -lSOGo$(LIBRARY_NAME_SUFFIX)

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/library.make
include $(GNUSTEP_MAKEFILES)/tool.make
-include GNUmakefile.postamble
-include ../../fhslib.make
-include ../../fhstools.make
