# GNUstep makefile

include ../common.make

BUNDLE_NAME = Sieve

Sieve_PRINCIPAL_CLASS = SOGoSieveProduct

Sieve_OBJC_FILES += \
	Product.m		\
	SOGoSieveBaseObject.m	\
	SOGoSieveScriptsFolder.m\
	SOGoSieveScriptObject.m	\

Sieve_RESOURCE_FILES += \
	Version		\
	product.plist	\

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
