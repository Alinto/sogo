# GNUstep makefiles

include ../common.make

BUNDLE_NAME = iCalHTTP

iCalHTTP_PRINCIPAL_CLASS = iCalHTTPProduct

iCalHTTP_LANGUAGES = English French

iCalHTTP_OBJC_FILES = \
	iCalHTTPProduct.m	\
	SOGoICalHTTPHandler.m	\
	SOGoICalFileFetch.m	\
	SOGoICalFilePublish.m	\

iCalHTTP_RESOURCE_FILES += \
	Version		\
	product.plist

ADDITIONAL_INCLUDE_DIRS += \
	-I.. -I../.. -I../../..

# make

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
include ../../fhsbundle.make
