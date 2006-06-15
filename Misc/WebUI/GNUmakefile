# $Id$

include $(GNUSTEP_MAKEFILES)/common.make

WOAPP_NAME = WebUI

WebUI_OBJC_FILES = \
	WebUI_main.m	\
	Application.m	\
	Session.m	\
	DirectAction.m	\


ADDITIONAL_INCLUDE_DIRS = -INGExtensions -INGExtensions/NGLogging

WebUI_COMPONENTS = \
	Main.wo		\


WebUI_RESOURCE_FILES = \


WebUI_WEBSERVER_RESOURCE_FILES := \
	$(shell find WebServerResources -type f -print) 


WebUI_SUBPROJECTS = \
	NGExtensions	\


-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/woapp.make
-include GNUmakefile.postamble
