# GNUstep makefiles

include ../../config.make
include $(GNUSTEP_MAKEFILES)/common.make
include ./Version

GNUSTEP_INSTALLATION_DIR = ${GNUSTEP_LOCAL_ROOT}

ifneq ($(frameworks),yes)
LIBRARY_NAME = libGDLContentStore
else
FRAMEWORK_NAME = GDLContentStore
endif

libGDLContentStore_PCH_FILE = common.h
libGDLContentStore_INTERFACE_VERSION=$(MAJOR_VERSION).$(MINOR_VERSION)
libGDLContentStore_VERSION=$(MAJOR_VERSION).$(MINOR_VERSION).$(SUBMINOR_VERSION)

libGDLContentStore_HEADER_FILES_DIR         = .
libGDLContentStore_HEADER_FILES_INSTALL_DIR = /GDLContentStore
FHS_HEADER_FILES_INSTALL_DIR = $(libGDLContentStore_HEADER_FILES_INSTALL_DIR)

libGDLContentStore_HEADER_FILES +=		\
	NSURL+GCS.h				\
	EOAdaptorChannel+GCS.h			\
	\
	GCSAlarmsFolder.h			\
	GCSContext.h				\
	GCSFieldInfo.h				\
	GCSFolder.h				\
	GCSFolderManager.h			\
	GCSFolderType.h				\
	GCSChannelManager.h			\
	GCSSessionsFolder.h			\
	GCSSpecialQueries.h			\
	GCSStringFormatter.h			\

libGDLContentStore_OBJC_FILES +=		\
	NSURL+GCS.m				\
	EOAdaptorChannel+GCS.m			\
	EOQualifier+GCS.m			\
	\
	GCSAlarmsFolder.m			\
	GCSContext.m				\
	GCSFieldInfo.m				\
	GCSFolder.m				\
	GCSFolderManager.m			\
	GCSFolderType.m				\
	GCSChannelManager.m			\
	GCSSessionsFolder.m			\
	GCSSpecialQueries.m			\
	GCSStringFormatter.m			\

# framework support

GDLContentStore_PCH_FILE     = $(libGDLContentStore_PCH_FILE)
GDLContentStore_HEADER_FILES = $(libGDLContentStore_HEADER_FILES)
GDLContentStore_OBJC_FILES   = $(libGDLContentStore_OBJC_FILES)
GDLContentStore_SUBPROJECTS  = $(libGDLContentStore_SUBPROJECTS)

# Type models
TYPEMODELS_DIR = $(SOGO_TYPEMODELS)

libGDLContentStore_TYPEMODELS += \
	appointment.ocs	\
	contact.ocs \
	appointment-oracle.ocs \
	contact-oracle.ocs

# building

-include GNUmakefile.preamble
ifneq ($(frameworks),yes)
ifneq ($(FHS_INSTALL_ROOT),)
GNUSTEP_HEADERS=$(DESTDIR)$(FHS_INSTALL_ROOT)/include
endif
GNUSTEP_TARGET_LDIR=sogo
include $(GNUSTEP_MAKEFILES)/library.make
else
include $(GNUSTEP_MAKEFILES)/framework.make
endif
include $(GNUSTEP_MAKEFILES)/tool.make
-include GNUmakefile.postamble
