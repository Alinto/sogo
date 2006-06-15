# $Id: GNUmakefile,v 1.13 2004/06/08 11:41:13 helge Exp $

include $(GNUSTEP_MAKEFILES)/common.make

WOAPP_NAME = dbd

dbd_OBJC_FILES += \
	dbd.m			\
	\
	Frame.m			\
	MainPage.m		\
	DSoAuthenticator.m	\
	\
	DSoObject.m		\
	DSoHost.m		\
	DSoTable.m		\
	DSoDatabase.m		\
	DSoDatabaseManager.m	\
	DSoUser.m		\
	DSoUserManager.m	\
	DSoField.m		\
	\
	DHostView.m		\
	DDatabaseManager.m	\
	DDatabase.m		\
	DTable.m		\

dbd_RESOURCE_FILES += \
	Version			\
	product.plist		\
	\
	Frame.wox		\
	MainPage.wox		\
	\
	DHostView.wox		\
	DDatabaseManager.wox	\
	DDatabase.wox		\
	DTable.wox		\

dbd_WEBSERVER_RESOURCE_FILES +=

ADDITIONAL_TOOL_LIBS += -lGDLAccess

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/woapp.make
-include GNUmakefile.postamble
