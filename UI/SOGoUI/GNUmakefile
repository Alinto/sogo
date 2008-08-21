# GNUstep makefile

include ../common.make
-include ../../config.make
include $(GNUSTEP_MAKEFILES)/common.make
include ../../Version
include ./Version 

LIBRARY_NAME = libSOGoUI

libSOGoUI_HEADER_FILES_DIR         = .
libSOGoUI_HEADER_FILES_INSTALL_DIR = /SOGoUI
libSOGoUI_INTERFACE_VERSION	   = $(MAJOR_VERSION).$(MINOR_VERSION)

libSOGoUI_HEADER_FILES +=	\
	\
	UIxJSClose.h		\
	UIxComponent.h		\
	SOGoAptFormatter.h	\
	WOContext+UIx.h		\

libSOGoUI_OBJC_FILES +=		\
	\
	UIxJSClose.m		\
	UIxComponent.m		\
	SOGoAptFormatter.m	\
	WOContext+UIx.m		\
	SOGoACLAdvisory.m \
	SOGoFolderAdvisory.m

# make

-include GNUmakefile.preamble
ifneq ($(FHS_INSTALL_ROOT),)
GNUSTEP_HEADERS=$(DESTDIR)$(FHS_INSTALL_ROOT)/include
endif
include $(GNUSTEP_MAKEFILES)/library.make
-include GNUmakefile.postamble
