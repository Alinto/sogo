# GNUstep makefile

include ../common.make

BUNDLE_NAME = MainUI

MainUI_PRINCIPAL_CLASS = MainUIProduct

MainUI_LANGUAGES = $(SOGO_LANGUAGES)

MainUI_OBJC_FILES += \
	MainUIProduct.m		\
	SOGoRootPage.m		\
	SOGoUserHomePage.m	\
	SOGoBrowsersPanel.m	\
	SOGoMicrosoftActiveSyncActions.m \
	SOGoAPIActions.m \

ifeq ($(saml2_config), yes)
	MainUI_OBJC_FILES += SOGoSAML2Actions.m
endif

MainUI_RESOURCE_FILES += 	\
	product.plist		\
	SOGoProfile.sql \
	SOGoProfile-mysql.sql \
	SOGoProfile-oracle.sql \
	OCSFolderInfo.sql \
	OCSFolderInfo-oracle.sql \
	OCSStore.sql \
	OCSStore-mysql.sql \
	OCSStore-oracle.sql \
	OCSAcl-mysql.sql \
	OCSAcl-oracle.sql \
	OCSAcl-postgresql.sql \
	OCSCacheFolder-mysql.sql \
	OCSCacheFolder-oracle.sql \
	OCSCacheFolder-postgresql.sql

MainUI_LOCALIZED_RESOURCE_FILES += \
	Locale Localizable.strings

ADDITIONAL_INCLUDE_DIRS += -I../../SOPE/
ADDITIONAL_LIB_DIRS += -L../../SOPE/GDLContentStore/obj/
ADDITIONAL_LDFLAGS += -Wl,--rpath,$(SOGO_SYSLIBDIR)/sogo

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
