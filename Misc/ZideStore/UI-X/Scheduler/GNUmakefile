# $Id: GNUmakefile,v 1.4 2004/06/04 16:15:23 znek Exp $

include $(GNUSTEP_MAKEFILES)/common.make

BUNDLE_NAME        = SchedulerUI
BUNDLE_EXTENSION   = .zsp
BUNDLE_INSTALL_DIR = $(GNUSTEP_USER_ROOT)/Library/ZideStore12

SchedulerUI_PRINCIPAL_CLASS = SchedulerUIProduct

SchedulerUI_OBJC_FILES = \
	SchedulerUIProduct.m	\
	UIxAppointmentFormatter.m \
	UIxCalView.m		\
	UIxCalWeekView.m	\
	UIxCalMonthView.m	\
	UIxAptTableView.m	\
	\
	UIxCalWeekOverview.m	\
	UIxCalMonthOverview.m	\
	UIxAppointmentView.m	\
	UIxAppointmentEditor.m	\
	UIxCalSelectTab.m \
	UIxCalDateLabel.m \
	UIxCalBackForthNavView.m \

SchedulerUI_RESOURCE_FILES += \
	Version				\
	product.plist			\
	\
	UIxAptTableView.wox		\
	UIxCalWeekOverview.wox		\
	UIxCalMonthOverview.wox		\
	UIxAppointmentView.wox		\
	UIxAppointmentEditor.wox		\
	UIxCalSelectTab.wox \
	UIxCalDateLabel.wox \
	UIxCalBackForthNavView.wox \
	images/next_week.gif		\
	images/previous_week.gif						\
	images/icon_apt_chart.gif						\
	images/icon_apt_overview.gif				\
	images/icon_apt_chart_inactive.gif		\
	images/icon_apt_overview_inactive.gif \
	images/icon_apt_column_view.gif				\
	images/icon_apt_list.gif							\
	images/icon_apt_list_inactive.gif			\


ifeq ($(FOUNDATION_LIB),apple)
ZIDESTORE=$(GNUSTEP_USER_ROOT)/Library/Headers/ZideStore12
else
ZIDESTORE=$(GNUSTEP_USER_ROOT)/Headers/ZideStore12
endif

ADDITIONAL_INCLUDE_DIRS += \
	-I. \
	-I.. \
	-I$(ZIDESTORE)/Frontend -I$(ZIDESTORE)/Backend \
	-I$(ZIDESTORE) -I$(ZIDESTORE)/Common

# make

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
