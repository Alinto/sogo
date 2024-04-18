
# GNUstep makefile

include common.make

BUNDLE_NAME = API

API_PRINCIPAL_CLASS = SOGoAPIProduct

API_OBJC_FILES =			\
	SOGoAPIProduct.m		\
	SOGoAPI.m               \
	SOGoAPIVersion.m        \
	SOGoAPIDispatcher.m

API_RESOURCE_FILES +=		\
	product.plist

API_LANGUAGES = $(SOGO_LANGUAGES)

API_LOCALIZED_RESOURCE_FILES = Localizable.strings

ADDITIONAL_INCLUDE_DIRS += -I../SOPE/ -I../SoObjects/

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
