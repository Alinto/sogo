# common make file for UI bundles

include ../../config.make
include $(GNUSTEP_MAKEFILES)/common.make
include ../../Version
-include ./Version

BUNDLE_EXTENSION   = .SOGo
BUNDLE_INSTALL_DIR = $(SOGO_LIBDIR)

ADDITIONAL_INCLUDE_DIRS += \
	-I..		\
	-I../..		\
	-I../../..	\
	-I../../SoObjects \
	-I../../SOPE

ifeq ($(GNUSTEP_BUILD_DIR),)

ADDITIONAL_LIB_DIRS += 				\
        -L../../SOPE/NGCards/$(GNUSTEP_OBJ_DIR)	\
	-L../SOGoUI/$(GNUSTEP_OBJ_DIR)		\
	-L../../SoObjects/SOGo/$(GNUSTEP_OBJ_DIR)

else
RELBUILD_DIR_libNGCards = \
	$(GNUSTEP_BUILD_DIR)/../../SOPE/NGCards/$(GNUSTEP_OBJ_DIR_NAME)
RELBUILD_DIR_libSOGo = \
	$(GNUSTEP_BUILD_DIR)/../../SoObjects/SOGo/$(GNUSTEP_OBJ_DIR_NAME)
RELBUILD_DIR_libSOGoUI = \
	$(GNUSTEP_BUILD_DIR)/../SOGoUI/$(GNUSTEP_OBJ_DIR_NAME)
RELBUILD_DIR_libOGoContentStore = \
	$(GNUSTEP_BUILD_DIR)/../../OGoContentStore/$(GNUSTEP_OBJ_DIR_NAME)

ADDITIONAL_LIB_DIRS += 				\
	-L$(RELBUILD_DIR_libNGCards)		\
	-L$(RELBUILD_DIR_libSOGo)		\
	-L$(RELBUILD_DIR_libSOGoUI)		\
	-L$(RELBUILD_DIR_libOGoContentStore)
endif

SYSTEM_LIB_DIR += -L/usr/local/lib -L/usr/lib

BUNDLE_LIBS += \
	-lSOGoUI				\
	-lSOGo					\
	-lOGoContentStore			\
	-lGDLContentStore			\
	-lGDLAccess				\
	-lNGObjWeb				\
	-lNGMime -lNGCards -lNGLdap		\
	-lNGStreams -lNGExtensions -lEOControl	\
	-lXmlRpc -lDOM -lSaxObjC
