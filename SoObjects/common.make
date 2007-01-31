# common make file for SoObject bundles

-include ../../config.make
include $(GNUSTEP_MAKEFILES)/common.make
include ../../Version
include ./Version

BUNDLE_EXTENSION     = .SOGo
BUNDLE_INSTALL_DIR   = $(GNUSTEP_USER_ROOT)/Library/SOGo-$(MAJOR_VERSION).$(MINOR_VERSION)
WOBUNDLE_EXTENSION   = $(BUNDLE_EXTENSION)
WOBUNDLE_INSTALL_DIR = $(BUNDLE_INSTALL_DIR)

# SYSTEM_LIB_DIR += -L/usr/local/lib -L/usr/lib

ADDITIONAL_INCLUDE_DIRS += \
	-I.. \
	-I../..

ADDITIONAL_LIB_DIRS += \
        -L../SOGo/$(GNUSTEP_OBJ_DIR)/ \
	-L../../SOGo/$(GNUSTEP_OBJ_DIR)/ \
	-L../../OGoContentStore/$(GNUSTEP_OBJ_DIR)/ \
        -L/usr/local/lib

BUNDLE_LIBS += \
	-lSOGo					\
	-lGDLContentStore			\
	-lGDLAccess				\
	-lNGObjWeb				\
	-lNGCards -lNGMime -lNGLdap		\
	-lNGStreams -lNGExtensions -lEOControl	\
	-lXmlRpc -lDOM -lSaxObjC

ADDITIONAL_BUNDLE_LIBS += $(BUNDLE_LIBS)
