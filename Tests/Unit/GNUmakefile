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
	SaxXMLReaderFactory+SOGoTests.m \
	\
	TestVersit.m \
	TestiCalTimeZonePeriod.m \
	TestiCalRecurrenceCalculator.m \
	\
	TestSBJsonParser.m \
	\
	TestNGMimeAddressHeaderFieldGenerator.m \
	TestNSData+Crypto.m \
	TestNSString+Crypto.m \
	TestNSString+URLEscaping.m \
	TestNSString+Utilities.m

TEST_TOOL_NAME = $(TEST_TOOL)

TEST_TOOL_CPPFLAGS += \
	-Wall -D_GNU_SOURCE -I../SOPE/ -I../SoObjects/ -I../UI/

ADDITIONAL_LIB_DIRS += \
	-L../SoObjects/SOGo -lSOGo -lNGMime -lNGCards -lGDLContentStore -lNGExtensions -lSBJson -lobjc -L/usr/local/lib  -lSaxObjC

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/test-tool.make
-include GNUmakefile.postamble

