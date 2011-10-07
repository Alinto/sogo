# GNUstep makefile

include ../config.make
include $(GNUSTEP_MAKEFILES)/common.make
include ../Version

ADDITIONAL_INCLUDE_DIRS += -I/usr/include/python2.6/ 
ADDITIONAL_LIB_DIRS += -L../SOPE/GDLContentStore/obj/
ADDITIONAL_LDFLAGS += -Wl,--no-as-needed
ADDITIONAL_LDFLAGS += -lpython2.6

SOGOD     = sogod
TOOL_NAME = $(SOGOD)
$(SOGOD)_INSTALL_DIR = $(SOGO_ADMIN_TOOLS)

$(SOGOD)_OBJC_FILES += \
	sogod.m			\
	SOGo.m			\
	SOGo+DAV.m
#	NSException+Stacktrace.m

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/tool.make
-include GNUmakefile.postamble
