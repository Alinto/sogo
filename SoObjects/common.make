# common make file for SoObject bundles

include ../../config.make
include $(GNUSTEP_MAKEFILES)/common.make
include ../../Version

NEEDS_GUI=no
BUNDLE_EXTENSION     = .SOGo
BUNDLE_INSTALL_DIR   = $(SOGO_LIBDIR)
WOBUNDLE_EXTENSION   = $(BUNDLE_EXTENSION)
WOBUNDLE_INSTALL_DIR = $(BUNDLE_INSTALL_DIR)

# SYSTEM_LIB_DIR += -L/usr/local/lib -L/usr/lib

ADDITIONAL_INCLUDE_DIRS += \
	-I.. \
	-I../.. \
        -I../../SOPE

ADDITIONAL_LIB_DIRS += \
        -L../SOGo/SOGo.framework/ \
	-L../../SOGo/$(GNUSTEP_OBJ_DIR)/ \
	-L../../OGoContentStore/$(GNUSTEP_OBJ_DIR)/ \
	-L../../SOPE/NGCards/$(GNUSTEP_OBJ_DIR)/ \
        -L/usr/local/lib

BUNDLE_LIBS += \
	-lSOGo					\
	-lGDLContentStore			\
	-lGDLAccess				\
	-lNGObjWeb				\
	-lNGCards -lNGMime -lNGLdap		\
	-lNGStreams -lNGExtensions -lEOControl	\
	-lDOM -lSaxObjC -lSBJson

ADDITIONAL_BUNDLE_LIBS += $(BUNDLE_LIBS)
