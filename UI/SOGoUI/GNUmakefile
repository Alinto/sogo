# GNUstep makefile

-include ../../config.make
include $(GNUSTEP_MAKEFILES)/common.make
include ../../Version
include ./Version 

LIBRARY_NAME = libSOGoUI

libSOGoUI_HEADER_FILES_DIR         = .
libSOGoUI_HEADER_FILES_INSTALL_DIR = /SOGoUI
FHS_HEADER_DIRS = SOGoUI

libSOGoUI_HEADER_FILES +=	\
	\
	UIxComponent.h		\
	SOGoDateFormatter.h	\
	SOGoAptFormatter.h	\
	SOGoJSStringFormatter.h	\
	WOContext+UIx.h		\

libSOGoUI_OBJC_FILES +=		\
	\
	UIxComponent.m		\
	SOGoDateFormatter.m	\
	SOGoAptFormatter.m	\
	SOGoJSStringFormatter.m \
	WOContext+UIx.m		\

# make

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/library.make
-include GNUmakefile.postamble
-include ../../fhslib.make
