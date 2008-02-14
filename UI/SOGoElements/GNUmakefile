# GNUstep makefile

include ../../config.make
include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME      = SOGoElements
BUNDLE_EXTENSION = .wox
BUNDLE_INSTALL_DIR = $(SOPE_WOXBUILDERS)

SOGoElements_PRINCIPAL_CLASS = SOGoElementsBundle

SOGoElements_OBJC_FILES = \
	SOGoElementsBundle.m \
	SOGoElementsBuilder.m \
	SOGoIEConditional.m

# building

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
