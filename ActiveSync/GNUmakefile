
# GNUstep makefile

include common.make

BUNDLE_NAME = ActiveSync

ActiveSync_PRINCIPAL_CLASS = ActiveSyncProduct

ActiveSync_OBJC_FILES =			\
	ActiveSyncProduct.m		\
	iCalAlarm+ActiveSync.m		\
	iCalEvent+ActiveSync.m		\
	iCalRecurrenceRule+ActiveSync.m \
	iCalTimeZone+ActiveSync.m	\
	iCalToDo+ActiveSync.m		\
	NSCalendarDate+ActiveSync.m	\
	NSData+ActiveSync.m		\
	NSDate+ActiveSync.m		\
	NGDOMElement+ActiveSync.m	\
	NGMimeMessage+ActiveSync.m	\
	NGVCard+ActiveSync.m		\
	NSArray+SyncCache.m		\
	NSString+ActiveSync.m		\
	SOGoActiveSyncDispatcher.m	\
	SOGoActiveSyncDispatcher+Sync.m \
	SOGoMailObject+ActiveSync.m 	\
	SOGoSyncCacheObject.m		\
	SoObjectWebDAVDispatcher+ActiveSync.m

ActiveSync_RESOURCE_FILES +=		\
	product.plist

ADDITIONAL_OBJCFLAGS += -Wno-deprecated-declarations
ADDITIONAL_INCLUDE_DIRS += -I../SOPE/ -I../SoObjects/
ADDITIONAL_LIB_DIRS += -L../SOPE/GDLContentStore/obj/ -L../SOPE/NGCards/obj/
ADDITIONAL_INCLUDE_DIRS += -I/usr/include/libwbxml-1.0/
ADDITIONAL_LDFLAGS += -Wl,--no-as-needed -lwbxml2

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
