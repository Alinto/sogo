# GNUstep makefile

include ../../../config.make
include $(GNUSTEP_MAKEFILES)/common.make
-include ./Version

BUNDLE_NAME        = versitCardsSaxDriver
BUNDLE_EXTENSION   = .sax
BUNDLE_INSTALL_DIR = ${SOPE_SAXDRIVERS}/

versitCardsSaxDriver_PRINCIPAL_CLASS = VSCardSaxDriver

versitCardsSaxDriver_PCH_FILE = common.h

versitCardsSaxDriver_OBJC_FILES =	\
	VSSaxDriver.m		\
	VSCardSaxDriver.m	\
	VSStringFormatter.m	\

versitCardsSaxDriver_RESOURCE_FILES = bundle-info.plist

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
