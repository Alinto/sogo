
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
	MAPIStoreMapping.m \
	MAPIStoreTypes.m \
	\
	SOGoMAPIFSFolder.m \
	SOGoMAPIFSMessage.m \
	\
	MAPIStoreAttachment.m \
	MAPIStoreAttachmentTable.m \
	MAPIStoreContext.m \
	MAPIStoreEmbeddedMessage.m \
	MAPIStoreFolder.m \
	MAPIStoreMessage.m \
	MAPIStoreObject.m \
	MAPIStoreTable.m \
	MAPIStoreMessageTable.m \
	MAPIStoreFolderTable.m \
	\
	MAPIStoreFSBaseContext.m \
	MAPIStoreFSFolder.m \
	MAPIStoreFSMessage.m \
	MAPIStoreFSMessageTable.m \
	\
	MAPIStoreFAIMessage.m \
	MAPIStoreFAIMessageTable.m \
	\
	MAPIStoreGCSBaseContext.m \
	MAPIStoreGCSFolder.m \
	MAPIStoreGCSMessage.m \
	MAPIStoreGCSMessageTable.m \
	\
	MAPIStoreCalendarAttachment.m \
	MAPIStoreCalendarContext.m \
	MAPIStoreCalendarFolder.m \
	MAPIStoreCalendarMessage.m \
	MAPIStoreCalendarMessageTable.m \
	MAPIStoreRecurrenceUtils.m \
	\
	MAPIStoreContactsContext.m \
	MAPIStoreContactsFolder.m \
	MAPIStoreContactsMessage.m \
	MAPIStoreContactsMessageTable.m \
	\
	MAPIStoreTasksContext.m \
	MAPIStoreTasksFolder.m \
	MAPIStoreTasksMessage.m \
	MAPIStoreTasksMessageTable.m \
	\
	MAPIStoreMailAttachment.m \
	MAPIStoreMailContext.m \
	MAPIStoreMailFolder.m \
	MAPIStoreMailFolderTable.m \
	MAPIStoreDraftsAttachment.m \
	MAPIStoreDraftsMessage.m \
	MAPIStoreMailMessage.m \
	MAPIStoreMailMessageTable.m \
	\
	MAPIStoreNotesContext.m \
	MAPIStoreNotesFolder.m \
	MAPIStoreNotesMessage.m \
	\
	MAPIStoreCommonViewsContext.m \
	MAPIStoreDeferredActionsContext.m \
	MAPIStoreFreebusyContext.m \
	MAPIStoreJournalContext.m \
	MAPIStoreRemindersContext.m \
	MAPIStoreScheduleContext.m \
	MAPIStoreSearchContext.m \
	MAPIStoreShortcutsContext.m \
	MAPIStoreViewsContext.m \
	\
	NSArray+MAPIStore.m \
	NSAutoreleasePool+MAPIStore.m \
	NSCalendarDate+MAPIStore.m \
	NSData+MAPIStore.m \
	NSObject+MAPIStore.m \
	NSString+MAPIStore.m \
	NSValue+MAPIStore.m \
	\
	EOBitmaskQualifier.m \
	EOQualifier+MAPIFS.m \

$(SOGOBACKEND)_RESOURCE_FILES += \
	product.plist

### cflags and libs
LIBMAPI_CFLAGS = $(shell pkg-config libmapi --cflags)
LIBMAPISTORE_CFLAGS = $(shell pkg-config libmapistore --cflags)

ifeq ($(LIBMAPISTORE_CFLAGS),)
all install::
	@echo "Cannot build the OpenChange SOGo backend (empty CFLAGS for libmapistore)"
else

LIBMAPI_LIBS = $(shell pkg-config libmapi --libs)
LIBMAPISTORE_LIBS = $(shell pkg-config libmapistore --libs) -lmapiproxy

ADDITIONAL_INCLUDE_DIRS += \
	-Werror -Wall \
	$(LIBMAPI_CFLAGS) \
	$(LIBMAPISTORE_CFLAGS) \
	-I../SoObjects -I../SOPE \
	-DBACKEND_BUNDLE_NAME="@\"$(BUNDLE_NAME)$(BUNDLE_EXTENSION)\"" \
	-DSOGO_BUNDLES_DIR="@\"$(BUNDLE_INSTALL_DIR)\""
ADDITIONAL_LIB_DIRS += -Wl,--as-needed \
	-L../SOGo/SOGo.framework/ -lSOGo \
	-L../../OGoContentStore/$(GNUSTEP_OBJ_DIR)/ -lOGoContentStore \
	 $(LIBMAPI_LIBS) \
	 $(LIBMAPISTORE_LIBS)

SAMBA_LIB_DIR = $(shell pkg-config libmapistore --variable=libdir)

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
include $(GNUSTEP_MAKEFILES)/library.make
-include GNUmakefile.postamble

endif
