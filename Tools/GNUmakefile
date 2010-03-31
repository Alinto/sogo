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

SOGO_SLAPD_SOCKD = sogo-slapd-sockd
$(SOGO_SLAPD_SOCKD)_INSTALL_DIR = $(SOGO_ADMIN_TOOLS)
$(SOGO_SLAPD_SOCKD)_OBJC_FILES += \
	sogo-slapd-sockd.m \
	\
	SOGoSockD.m \
	SOGoSockDScanner.m \
	SOGoSockDOperation.m \

TOOL_NAME = $(SOGO_TOOL) $(SOGO_SLAPD_SOCKD)

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/tool.make
-include GNUmakefile.postamble
