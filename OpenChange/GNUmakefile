
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
	MAPIStoreTypes.m \
	\
	MAPIStoreCalendarContext.m \
	MAPIStoreCommonViewsContext.m \
	MAPIStoreContactsContext.m \
	MAPIStoreDeferredActionsContext.m \
	MAPIStoreDeletedItemsContext.m \
	MAPIStoreDraftsContext.m \
	MAPIStoreFreebusyContext.m \
	MAPIStoreFSBaseContext.m \
	MAPIStoreGCSBaseContext.m \
	MAPIStoreJournalContext.m \
	MAPIStoreMailContext.m \
	MAPIStoreNotesContext.m \
	MAPIStoreOutboxContext.m \
	MAPIStoreRemindersContext.m \
	MAPIStoreScheduleContext.m \
	MAPIStoreSearchContext.m \
	MAPIStoreSentItemsContext.m \
	MAPIStoreShortcutsContext.m \
	MAPIStoreSpoolerContext.m \
	MAPIStoreTasksContext.m \
	MAPIStoreViewsContext.m \
	\
	MAPIStoreTable.m \
	MAPIStoreMessageTable.m \
	MAPIStoreFolderTable.m \
	MAPIStoreFSMessageTable.m \
	MAPIStoreGCSMessageTable.m \
	MAPIStoreFAIMessageTable.m \
	MAPIStoreCalendarMessageTable.m \
	MAPIStoreContactsMessageTable.m \
	MAPIStoreMailMessageTable.m \
	MAPIStoreMailFolderTable.m \
	MAPIStoreNotesMessageTable.m \
	MAPIStoreTasksMessageTable.m \
	\
	SOGoAppointmentObject+MAPIStore.m \
	SOGoContentObject+MAPIStore.m \
	SOGoContactGCSEntry+MAPIStore.m \
	SOGoDraftObject+MAPIStore.m \
	SOGoGCSFolder+MAPIStore.m \
	SOGoTaskObject+MAPIStore.m \
	\
	SOGoMAPIFSFolder.m \
	SOGoMAPIFSMessage.m \
	\
	NSArray+MAPIStore.m \
	NSCalendarDate+MAPIStore.m \
	NSData+MAPIStore.m \
	NSString+MAPIStore.m \
	NSValue+MAPIStore.m \
	\
	EOBitmaskQualifier.m \
	EOQualifier+MAPIFS.m

$(SOGOBACKEND)_RESOURCE_FILES += \
	product.plist

### cflags and libs
LIBMAPI_CFLAGS = $(shell pkg-config libmapistore --cflags)

ifeq ($(LIBMAPI_CFLAGS),)
all install::
	@echo "Cannot build the OpenChange SOGo backend (empty CFLAGS for libmapistore)"
else

LIBMAPI_LIBS = $(shell pkg-config libmapistore --libs) -lmapiproxy

ADDITIONAL_INCLUDE_DIRS += \
	-Werror -Wall \
	$(LIBMAPI_CFLAGS) \
	-I../SoObjects -I../SOPE \
	-DBACKEND_BUNDLE_NAME="@\"$(BUNDLE_NAME)$(BUNDLE_EXTENSION)\"" \
	-DSOGO_BUNDLES_DIR="@\"$(BUNDLE_INSTALL_DIR)\""
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
