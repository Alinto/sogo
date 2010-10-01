# GNUstep makefile

include ../config.make
include $(GNUSTEP_MAKEFILES)/common.make
include ../Version

ADDITIONAL_INCLUDE_DIRS += $(shell pkg-config libmapiproxy --cflags) -I../SoObjects -I../SOPE
ADDITIONAL_LIB_DIRS += -L../SOPE/GDLContentStore/obj/ $(shell pkg-config libmapiproxy --libs)

SAMBA_LIB_DIR = $(shell pkg-config libmapiproxy --variable=libdir)

MAPISTORESOGO = MAPIStoreSOGo
$(MAPISTORESOGO)_VERSION = 1.0.0
LIBRARY_NAME = $(MAPISTORESOGO)
$(MAPISTORESOGO)_INSTALL_DIR = $(SAMBA_LIB_DIR)/mapistore_backends

$(MAPISTORESOGO)_OBJC_FILES += \
	MAPIApplication.m \
	MAPIStoreAuthenticator.m \
	MAPIStoreContext.m \
	MAPIStoreMapping.m \
	MAPIStoreSOGo.m \
	\
	MAPIStoreCalendarContext.m \
	MAPIStoreContactsContext.m \
	MAPIStoreMailContext.m \
	\
	NSCalendarDate+MAPIStore.m \
	NSString+MAPIStore.m

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/library.make
-include GNUmakefile.postamble
