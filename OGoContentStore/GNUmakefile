# GNUstep makefile

include ../config.make
include $(GNUSTEP_MAKEFILES)/common.make
include ./Version

LIBRARY_NAME = libOGoContentStore

TYPEMODELS_DIR = $(SOGO_TYPEMODELS)

libOGoContentStore_HEADER_FILES_DIR         = .
libOGoContentStore_HEADER_FILES_INSTALL_DIR = /OGoContentStore
libOGoContentStore_INTERFACE_VERSION=$(MAJOR_VERSION).$(MINOR_VERSION)

ADDITIONAL_INCLUDE_DIRS += -I../SOPE
ADDITIONAL_LIB_DIRS += -L../SOPE/GDLContentStore/obj

libOGoContentStore_OBJC_FILES +=		\
	OCSiCalFieldExtractor.m			\
	OCSContactFieldExtractor.m		\

libOGoContentStore_TYPEMODELS += \
	appointment.ocs	\
	contact.ocs \
	appointment-oracle.ocs \
	contact-oracle.ocs

-include GNUmakefile.preamble
ifneq ($(FHS_INSTALL_ROOT),)
GNUSTEP_HEADERS=$(DESTDIR)$(FHS_INSTALL_ROOT)/include
endif
include $(GNUSTEP_MAKEFILES)/library.make
include $(GNUSTEP_MAKEFILES)/tool.make
-include GNUmakefile.postamble
