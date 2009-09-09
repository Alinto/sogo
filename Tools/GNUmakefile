# GNUstep makefile

include ../config.make
include $(GNUSTEP_MAKEFILES)/common.make
include ../Version

SOGO_TOOL = sogo-tool
$(SOGO_TOOL)_INSTALL_DIR = $(SOGO_ADMIN_TOOLS)
$(SOGO_TOOL)_OBJC_FILES += \
	sogo-tool.m \
	\
	SOGoTool.m \
	SOGoToolBackup.m \
	SOGoToolRestore.m \
	SOGoToolCheckDoubles.m \
	SOGoToolRemoveDoubles.m \

TOOL_NAME = $(SOGO_TOOL)

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/tool.make
-include GNUmakefile.postamble
