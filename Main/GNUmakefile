# GNUstep makefile

-include ../config.make
include $(GNUSTEP_MAKEFILES)/common.make
include ../Version
include ./Version

ADDITIONAL_INCLUDE_DIRS += -I../SOPE/ -D_GNU_SOURCE
ADDITIONAL_LIB_DIRS += -L../SOPE/GDLContentStore/obj/

SOGOD     = sogod-$(MAJOR_VERSION).$(MINOR_VERSION)
TOOL_NAME = $(SOGOD)

# daemon tool
all::
	@touch build.m

$(SOGOD)_OBJC_FILES += \
	sogod.m			\
#	NSException+Stacktrace.m\
	SOGo.m			\
	SOGoProductLoader.m	\
	build.m

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/tool.make
-include GNUmakefile.postamble
include fhs.make
