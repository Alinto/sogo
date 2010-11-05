# GNUstep makefile

include ../config.make
include $(GNUSTEP_MAKEFILES)/common.make
include ../Version

LIBMAPI_CFLAGS = $(shell pkg-config libmapistore --cflags)

ifeq ($(LIBMAPI_CFLAGS),)

all install::
	@echo "Cannot build the OpenChange SOGo backend (empty CFLAGS for libmapistore)"

else

LIBMAPI_LIBS = $(shell pkg-config libmapistore --libs) -lmapiproxy

ADDITIONAL_INCLUDE_DIRS += $(LIBMAPI_CFLAGS) -I../SoObjects -I../SOPE
ADDITIONAL_LIB_DIRS += -L../SOGo/SOGo.framework/ -lSOGo -L../SOPE/GDLContentStore/obj/ $(LIBMAPI_LIBS)

SAMBA_LIB_DIR = $(shell pkg-config libmapistore --variable=libdir)

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
	MAPIStoreTasksContext.m \
	\
	SOGoGCSFolder+MAPIStore.m \
	\
	NSArray+MAPIStore.m \
	NSData+MAPIStore.m \
	NSDate+MAPIStore.m \
	NSString+MAPIStore.m

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/library.make
-include GNUmakefile.postamble

endif
