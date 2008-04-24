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

TOOL_NAME = gcs_ls gcs_mkdir gcs_cat gcs_recreatequick gcs_gensql

libGDLContentStore_HEADER_FILES_DIR         = .
libGDLContentStore_HEADER_FILES_INSTALL_DIR = /GDLContentStore
FHS_HEADER_FILES_INSTALL_DIR = $(libGDLContentStore_HEADER_FILES_INSTALL_DIR)

libGDLContentStore_HEADER_FILES +=		\
	NSURL+GCS.h				\
	EOAdaptorChannel+GCS.h			\
	\
	GCSContext.h				\
	GCSFieldInfo.h				\
	GCSFolder.h				\
	GCSFolderManager.h			\
	GCSFolderType.h				\
	GCSChannelManager.h			\
	GCSFieldExtractor.h			\
	GCSStringFormatter.h			\

libGDLContentStore_OBJC_FILES +=		\
	NSURL+GCS.m				\
	EOAdaptorChannel+GCS.m			\
	EOQualifier+GCS.m			\
	\
	GCSContext.m				\
	GCSFieldInfo.m				\
	GCSFolder.m				\
	GCSFolderManager.m			\
	GCSFolderType.m				\
	GCSChannelManager.m			\
	GCSFieldExtractor.m			\
	GCSStringFormatter.m			\

gcs_ls_OBJC_FILES            += gcs_ls.m
gcs_mkdir_OBJC_FILES         += gcs_mkdir.m
gcs_cat_OBJC_FILES           += gcs_cat.m
gcs_gensql_OBJC_FILES        += gcs_gensql.m
gcs_recreatequick_OBJC_FILES += gcs_recreatequick.m


# framework support

GDLContentStore_PCH_FILE     = $(libGDLContentStore_PCH_FILE)
GDLContentStore_HEADER_FILES = $(libGDLContentStore_HEADER_FILES)
GDLContentStore_OBJC_FILES   = $(libGDLContentStore_OBJC_FILES)
GDLContentStore_SUBPROJECTS  = $(libGDLContentStore_SUBPROJECTS)


# building

-include GNUmakefile.preamble
ifneq ($(frameworks),yes)
ifneq ($(FHS_INSTALL_ROOT),)
GNUSTEP_HEADERS=$(DESTDIR)$(FHS_INSTALL_ROOT)/include
endif
include $(GNUSTEP_MAKEFILES)/library.make
else
include $(GNUSTEP_MAKEFILES)/framework.make
endif
include $(GNUSTEP_MAKEFILES)/tool.make
-include GNUmakefile.postamble
