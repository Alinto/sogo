# GNUstep makefile

-include ../config.make
include $(GNUSTEP_MAKEFILES)/common.make
include ./Version

LIBRARY_NAME = libOGoContentStore
TOOL_NAME    = test_quick_extract

TYPEMODELS_DIR = $(GNUSTEP_USER_ROOT)/Library/OCSTypeModels/

libOGoContentStore_HEADER_FILES_DIR         = .
libOGoContentStore_HEADER_FILES_INSTALL_DIR = /OGoContentStore
# no headers, commented out: FHS_HEADER_DIRS = OGoContentStore

libOGoContentStore_OBJC_FILES +=		\
	iCalEntityObject+OCS.m			\
	iCalRepeatableEntityObject+OCS.m	\
	\
	OCSiCalFieldExtractor.m			\
	OCSContactFieldExtractor.m		\

libOGoContentStore_TYPEMODELS += \
	appointment.ocs	\
	contact.ocs 	\
	acls.ocs


test_quick_extract_OBJC_FILES += \
	test_quick_extract.m

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/library.make
include $(GNUSTEP_MAKEFILES)/tool.make
-include GNUmakefile.postamble
-include ../fhslib.make
