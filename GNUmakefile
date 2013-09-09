# GNUstep makefile

-include config.make
include $(GNUSTEP_MAKEFILES)/common.make

SUBPROJECTS = \
	SOPE/NGCards \
	SOPE/GDLContentStore \
	OGoContentStore	\
	SoObjects	\
	Main		\
	Tools		\
	Tests/Unit	\

ifeq ($(webui),yes)
SUBPROJECTS += UI
endif

include $(GNUSTEP_MAKEFILES)/aggregate.make
