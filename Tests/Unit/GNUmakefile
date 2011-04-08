# GNUstep makefile

debug=yes

include ../../config.make
include $(GNUSTEP_MAKEFILES)/common.make
include ../../Version

TEST_TOOL = sogo-tests
$(TEST_TOOL)_INSTALL_DIR = $(SOGO_ADMIN_TOOLS)
$(TEST_TOOL)_OBJC_FILES += \
	sogo-tests.m \
	\
	SOGoTest.m \
	SOGoTestRunner.m \
	\
	TestiCalTimeZonePeriod.m \
	TestiCalRecurrenceCalculator.m \
	\
	TestSBJsonParser.m \
	\
	TestNGMimeAddressHeaderFieldGenerator.m \
	TestNSString+URLEscaping.m

TOOL_NAME = $(TEST_TOOL)

ADDITIONAL_INCLUDE_DIRS += \
	-D_GNU_SOURCE -I../SOPE/ -I../SoObjects/ -I../UI/

ADDITIONAL_LIB_DIRS += \
	-L../SoObjects/SOGo -lSOGo -lNGMime -lNGCards -lGDLContentStore -lNGExtensions -lSBJson -lobjc

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/tool.make
-include GNUmakefile.postamble

