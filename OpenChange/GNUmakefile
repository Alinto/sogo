# GNUstep makefile

include ../config.make
include $(GNUSTEP_MAKEFILES)/common.make
include ../Version

BACKEND_VERSION = 1.0.0

### bootstrap library
MAPISTORESOGO = MAPIStoreSOGo
LIBRARY_NAME = $(MAPISTORESOGO)

$(MAPISTORESOGO)_VERSION = $(BACKEND_VERSION)
$(MAPISTORESOGO)_INSTALL_DIR = $(SAMBA_LIB_DIR)/mapistore_backends

$(MAPISTORESOGO)_OBJC_FILES += \
	MAPIStoreSOGo.m

### backend bundle
SOGOBACKEND = SOGoBackend
BUNDLE_NAME = $(SOGOBACKEND)
BUNDLE_EXTENSION = .MAPIStore
BUNDLE_INSTALL_DIR = $(SOGO_LIBDIR)

$(SOGOBACKEND)_PRINCIPAL_CLASS = MAPIApplication

$(SOGOBACKEND)_OBJC_FILES += \
	MAPIApplication.m \
	MAPIStoreAuthenticator.m \
	MAPIStoreContext.m \
	MAPIStoreMapping.m \
	\
	MAPIStoreCalendarContext.m \
	MAPIStoreContactsContext.m \
	MAPIStoreMailContext.m \
	MAPIStoreTasksContext.m \
	\
	SOGoGCSFolder+MAPIStore.m \
	SOGoContactGCSEntry+MAPIStore.m \
	\
	NSArray+MAPIStore.m \
	NSData+MAPIStore.m \
	NSDate+MAPIStore.m \
	NSString+MAPIStore.m

$(SOGOBACKEND)_RESOURCE_FILES += \
	product.plist

### cflags and libs
LIBMAPI_CFLAGS = $(shell pkg-config libmapistore --cflags)

ifeq ($(LIBMAPI_CFLAGS),)
all install::
	@echo "Cannot build the OpenChange SOGo backend (empty CFLAGS for libmapistore)"
else

LIBMAPI_LIBS = $(shell pkg-config libmapistore --libs) -lmapiproxy

ADDITIONAL_INCLUDE_DIRS += $(LIBMAPI_CFLAGS) -I../SoObjects -I../SOPE -DBACKEND_BUNDLE_NAME="@\"$(BUNDLE_NAME)$(BUNDLE_EXTENSION)\"" -DSOGO_BUNDLES_DIR="@\"$(BUNDLE_INSTALL_DIR)\""
ADDITIONAL_LIB_DIRS += -Wl,--as-needed \
	-L../SOGo/SOGo.framework/ -lSOGo \
	-L../../OGoContentStore/$(GNUSTEP_OBJ_DIR)/ -lOGoContentStore \
	 $(LIBMAPI_LIBS)

SAMBA_LIB_DIR = $(shell pkg-config libmapistore --variable=libdir)

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
include $(GNUSTEP_MAKEFILES)/library.make
-include GNUmakefile.postamble

endif
