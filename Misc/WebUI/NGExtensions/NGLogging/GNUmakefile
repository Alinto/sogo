# $Id$

include $(GNUSTEP_MAKEFILES)/common.make


SUBPROJECT_NAME = NGLogging


ADDITIONAL_INCLUDE_DIRS += -I.. -I../..


NGLogging_OBJC_FILES = \
    NSObject+ExtendedLogging.m  \
    NGLogger.m                  \
    NGLogEvent.m                \
    NGLogAppender.m             \
    NGLogConsoleAppender.m      \

NGLogging_HEADER_FILES = \
    NGLogging.h                 \
    NSObject+ExtendedLogging.h  \
    NGLogger.h                  \
    NGLogEvent.h                \
    NGLogAppender.h             \
    NGLogConsoleAppender.h      \


-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/subproject.make
-include GNUmakefile.postamble
