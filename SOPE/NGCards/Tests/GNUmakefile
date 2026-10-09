# GNUstep makefile

include ../../../config.make
include $(GNUSTEP_MAKEFILES)/common.make

TEST_TOOL = ngcards-tests
$(TEST_TOOL)_OBJC_FILES = \
	TestNGVCardPhoto.m

TEST_TOOL_NAME = $(TEST_TOOL)

$(TEST_TOOL)_CPPFLAGS += \
	-Wall -D_GNU_SOURCE -I..

ADDITIONAL_LIB_DIRS += \
	-L../obj -lNGCards \
	-lNGExtensions -lSaxObjC -lNGStreams -lDOM -lEOControl -lobjc \
	-Wl,-rpath,../obj

include $(GNUSTEP_MAKEFILES)/test-tool.make
