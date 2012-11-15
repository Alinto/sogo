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

$(TEST_TOOL)_CPPFLAGS += \
	-Wall -D_GNU_SOURCE -I../../SOPE/ -I../../SoObjects/ -I../../UI/

ADDITIONAL_LIB_DIRS += \
	-L../../SoObjects/SOGo/SOGo.framework/Versions/Current -L../../SOPE/NGCards/obj -L../../SOPE/GDLContentStore/obj -lSOGo -lNGMime -lNGCards -lGDLContentStore -lNGExtensions -lSBJson -lobjc \
	-L/usr/local/lib  -lSaxObjC \
	-Wl,-rpath,../../SoObjects/SOGo/SOGo.framework/Versions/Current -Wl,-rpath,../../SOPE/NGCards/obj -Wl,-rpath,../../SOPE/GDLContentStore/obj -Wl,-rpath,../../OGoContentStore/obj
ADDITIONAL_LDFLAGS += -Wl,--no-as-needed

check ::
	./obj/sogo-tests

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/test-tool.make
-include GNUmakefile.postamble

