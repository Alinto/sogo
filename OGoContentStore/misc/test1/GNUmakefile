# $Id$

include $(GNUSTEP_MAKEFILES)/common.make

TOOL_NAME = test

test_OBJC_FILES += test1.m

ADDITIONAL_TOOL_LIBS += -lOGoContentStore

ADDITIONAL_LIB_DIRS += -L../../$(GNUSTEP_OBJ_DIR)

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/tool.make
-include GNUmakefile.postamble
