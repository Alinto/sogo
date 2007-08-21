# GNUstep makefile

-include ../../config.make
include $(GNUSTEP_MAKEFILES)/common.make

SOPE_VERSION = 4.7

BUNDLE_NAME      = SOGoElements
BUNDLE_EXTENSION = .wox
BUNDLE_INSTALL_DIR = $(GNUSTEP_INSTALLATION_DIR)/Library/WOxElemBuilders-$(SOPE_VERSION)/

SOGoElements_PRINCIPAL_CLASS = SOGoElementsBundle

SOGoElements_OBJC_FILES = \
	SOGoElementsBundle.m \
	SOGoElementsBuilder.m \
	SOGoIEConditional.m

# building

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
-include fhs.make
