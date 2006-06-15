# $Id: GNUmakefile,v 1.2 2003/12/09 17:38:42 helge Exp $

include $(GNUSTEP_MAKEFILES)/common.make

ZIDESTORE=$(GNUSTEP_USER_ROOT)/Headers/ZideStore12


BUNDLE_NAME        = CommonUI
BUNDLE_EXTENSION   = .zsp
BUNDLE_INSTALL_DIR = $(GNUSTEP_USER_ROOT)/Library/ZideStore12

LIBRARY_NAME = libZideStoreCommonUI


libZideStoreCommonUI_HEADER_FILES_DIR         = .
libZideStoreCommonUI_HEADER_FILES_INSTALL_DIR = $(ZIDESTORE)/Common

libZideStoreCommonUI_HEADER_FILES += \
	UIxComponent.h \

libZideStoreCommonUI_OBJC_FILES += \
	UIxComponent.m \


CommonUI_PRINCIPAL_CLASS = CommonUIProduct

CommonUI_OBJC_FILES += \
	CommonUIProduct.m	\
	UIxPageFrame.m		\
	UIxAppFrame.m		\
	UIxAppHeader.m		\
	UIxAppNavigation.m	\
	UIxWinClose.m	\
	UIxAppNavView.m	\
	\
	UIxElemBuilder.m \
	UIxTabView.m \
	UIxTabItem.m \


CommonUI_RESOURCE_FILES += \
	Version			\
	product.plist		\
	UIxPageFrame.wox	\
	UIxAppFrame.wox		\
	UIxAppHeader.wox	\
	UIxAppNavigation.wox	\
	UIxWinClose.wox \
	UIxAppNavView.wox \
	\
	zidestoreui.css		\
	calendar.css		\
	\
	images/OGoLogo.gif	\
	images/menu_logo_top.gif	\
	images/line_left.gif	\
	images/line_stretch.gif	\
	images/line_right.gif	\
	images/box_topleft.gif	\
	images/box_top.gif	\
	images/box_topright.gif	\
	images/box_left.gif	\
	images/box_right.gif	\
	images/box_botleft.gif	\
	images/box_bottom.gif\
	images/box_botright.gif\
	images/tab_selected.gif\
	images/tab_.gif\
	images/corner_right.gif\
	images/closewindow.gif

ADDITIONAL_INCLUDE_DIRS += \
	-I. \
	-I$(ZIDESTORE)/Frontend -I$(ZIDESTORE)/Backend -I$(ZIDESTORE)


# make

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/library.make
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
