# GNUstep makefile

-include ../config.make
include $(GNUSTEP_MAKEFILES)/common.make
include ./Version

LIBRARY_NAME = libOGoContentStore
TOOL_NAME    = test_quick_extract

TYPEMODELS_DIR = $(GNUSTEP_INSTALLATION_DIR)/Library/OCSTypeModels/

libOGoContentStore_HEADER_FILES_DIR         = .
libOGoContentStore_HEADER_FILES_INSTALL_DIR = /OGoContentStore
# no headers, commented out: FHS_HEADER_DIRS = OGoContentStore

ADDITIONAL_INCLUDE_DIRS += -I../SOPE/sope-gdl1/
ADDITIONAL_LIB_DIRS += -L../SOPE/sope-gdl1/GDLContentStore/obj/

libOGoContentStore_OBJC_FILES +=		\
	iCalEntityObject+OCS.m			\
	iCalRepeatableEntityObject+OCS.m	\
	\
	OCSiCalFieldExtractor.m			\
	OCSContactFieldExtractor.m		\

libOGoContentStore_TYPEMODELS += \
	appointment.ocs	\
	contact.ocs \
	appointment-oracle.ocs \
	contact-oracle.ocs

test_quick_extract_OBJC_FILES += \
	test_quick_extract.m

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/library.make
include $(GNUSTEP_MAKEFILES)/tool.make
-include GNUmakefile.postamble
-include ../fhslib.make
