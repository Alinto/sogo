# GNUstep makefile

include ../common.make

BUNDLE_NAME = SchedulerUI

SchedulerUI_PRINCIPAL_CLASS = SchedulerUIProduct

SchedulerUI_LANGUAGES = English French German

SchedulerUI_OBJC_FILES =		\
	SchedulerUIProduct.m		\
					\
	UIxCalMainView.m		\
					\
	UIxCalFilterPanel.m		\
	UIxCalDayTable.m		\
					\
	UIxCalDateSelector.m		\
					\
	UIxComponent+Agenor.m		\
	UIxCalView.m			\
	UIxCalAptListView.m		\
	UIxCalDayView.m			\
	UIxCalWeekView.m		\
	UIxCalMonthView.m		\
	UIxAptTableView.m		\
					\
	UIxCalDayOverview.m		\
	UIxCalDayChartview.m		\
	UIxCalDayListview.m		\
	UIxCalWeekOverview.m		\
	UIxCalWeekChartview.m		\
	UIxCalWeekListview.m		\
	UIxCalWeekColumnsview.m		\
	UIxCalMonthOverview.m		\
	UIxCalYearOverview.m		\
	UIxCalInlineMonthOverview.m	\
	UIxAppointmentView.m		\
	UIxAppointmentEditor.m		\
	UIxCalSelectTab.m		\
	UIxCalDateLabel.m		\
	UIxCalBackForthNavView.m	\
	UIxAppointmentProposal.m	\
	UIxDatePicker.m			\
	UIxTimeDateControl.m		\
	UIxCalInlineAptView.m		\
	UIxCalScheduleOverview.m	\
	UIxCalParticipationStatusView.m	\
#	UIxCalDayPrintview.m		\
#	UIxCalWeekPrintview.m		\
#	UIxCalMonthPrintview.m		\
#	UIxAppointmentPrintview.m	\

SchedulerUI_RESOURCE_FILES += \
	Version		\
	product.plist	

SchedulerUI_RESOURCE_FILES += \
	Toolbars/SOGoAppointmentFolder.toolbar

SchedulerUI_LOCALIZED_RESOURCE_FILES += \
	Localizable.strings		\

# if SoProduct is fixed to enable localized resources, add this to
# SchedulerUI_LOCALIZED_RESOURCE_FILES instead
SchedulerUI_RESOURCE_FILES +=		\
	cycles.plist			\

# make

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
include ../../fhsbundle.make
