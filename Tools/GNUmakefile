# GNUstep makefile

include ../config.make
include $(GNUSTEP_MAKEFILES)/common.make
include ../Version

SOGO_CHECKDOUBLES = sogo-contacts-checkdoubles
$(SOGO_CHECKDOUBLES)_INSTALL_DIR = $(SOGO_ADMIN_TOOLS)
$(SOGO_CHECKDOUBLES)_OBJC_FILES += \
	sogo-contacts-checkdoubles.m

SOGO_REMOVEDOUBLES = sogo-contacts-removedoubles
$(SOGO_REMOVEDOUBLES)_INSTALL_DIR = $(SOGO_ADMIN_TOOLS)
$(SOGO_REMOVEDOUBLES)_OBJC_FILES += \
	sogo-contacts-removedoubles.m

TOOL_NAME = $(SOGO_CHECKDOUBLES) $(SOGO_REMOVEDOUBLES)

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/tool.make
-include GNUmakefile.postamble
