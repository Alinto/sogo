# GNUstep makefile

-include config.make
include $(GNUSTEP_MAKEFILES)/common.make

SUBPROJECTS = \
	SOPE/NGCards \
	SOPE/GDLContentStore \
	OGoContentStore	\
	SoObjects	\
	Tools		\
	Tests/Unit

ifeq ($(daemon),yes)
SUBPROJECTS += Main
endif

ifeq ($(webui),yes)
SUBPROJECTS += UI
endif

include $(GNUSTEP_MAKEFILES)/aggregate.make
