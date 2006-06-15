# $Id: GNUmakefile,v 1.2 2003/10/13 08:37:36 helge Exp $

include $(GNUSTEP_MAKEFILES)/common.make

TOOL_NAME = \
	ldapPersonExporter \
	findLongestEMailAddress \
	personalFolderInfoInserts \
        adaptorChannelInserts

ldapPersonExporter_OBJC_FILES = lpe.m
ldapPersonExporter_TOOL_LIBS += -lNGLdap

findLongestEMailAddress_OBJC_FILES = lmail.m

personalFolderInfoInserts_OBJC_FILES = pfinserts.m

adaptorChannelInserts_OBJC_FILES = inserts.m NSArray+random.m
adaptorChannelInserts_TOOL_LIBS += -lGDLAccess


-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/tool.make
-include GNUmakefile.postamble
