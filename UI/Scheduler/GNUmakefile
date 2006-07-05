# GNUstep makefile

include ../common.make

BUNDLE_NAME = SchedulerUI

SchedulerUI_PRINCIPAL_CLASS = SchedulerUIProduct

SchedulerUI_LANGUAGES = English French German

SchedulerUI_OBJC_FILES =		\
	SchedulerUIProduct.m		\
	iCalPerson+UIx.m		\
	NSCalendarDate+UIx.m		\
	SOGoAppointment+UIx.m		\
	UIxComponent+Agenor.m		\
	UIxCalView.m			\
	UIxCalDayView.m			\
	UIxCalWeekView.m		\
	UIxCalMonthView.m		\
	UIxAptTableView.m		\
					\
	UIxCalDayOverview.m		\
	UIxCalDayChartview.m		\
	UIxCalDayListview.m		\
	UIxCalDayPrintview.m		\
	UIxCalWeekOverview.m		\
	UIxCalWeekChartview.m		\
	UIxCalWeekListview.m		\
	UIxCalWeekColumnsview.m		\
	UIxCalWeekPrintview.m		\
	UIxCalMonthOverview.m		\
	UIxCalMonthPrintview.m		\
	UIxCalYearOverview.m		\
	UIxCalInlineMonthOverview.m	\
	UIxAppointmentView.m		\
	UIxAppointmentPrintview.m	\
	UIxAppointmentEditor.m		\
	UIxCalSelectTab.m		\
	UIxCalDateLabel.m		\
	UIxCalBackForthNavView.m	\
	UIxAppointmentProposal.m	\
	UIxDatePicker.m			\
	UIxDatePickerScript.m		\
	UIxTimeSelector.m		\
	UIxTimeDateControl.m		\
	UIxCalInlineAptView.m		\
	UIxCalScheduleOverview.m	\
	UIxCalParticipationStatusView.m	\
	\
	iCalRecurrenceRule+SOGo.m	\

SchedulerUI_RESOURCE_FILES += \
	Version		\
	product.plist

SchedulerUI_RESOURCE_FILES += \
	images/next_week.gif			\
	images/previous_week.gif		\
	images/icon_view_overview.gif		\
	images/icon_view_overview_inactive.gif	\
	images/icon_view_chart.gif		\
	images/icon_view_chart_inactive.gif	\
	images/icon_view_list.gif		\
	images/icon_view_list_inactive.gif	\
	images/icon_view_columns.gif		\
	images/icon_view_columns_inactive.gif	\
	images/icon_popupcalendar.gif		\
	images/first.gif			\
	images/previous.gif			\
	images/next.gif				\
	images/last.gif				\
	images/green_corner.gif			\
	images/invisible_space_2.gif		\
	images/apt_icon_private.gif		\
	images/day-view.png			\
	images/delete.png			\
	images/edit.png				\
	images/goto-today.png			\
	images/month-view.png			\
	images/multiweek-view.png		\
	images/new-event.png			\
	images/new-task.png			\
	images/week-view.png

SchedulerUI_LOCALIZED_RESOURCE_FILES += \
	Localizable.strings		\

# if SoProduct is fixed to enable localized resources, add this to
# SchedulerUI_LOCALIZED_RESOURCE_FILES instead
SchedulerUI_RESOURCE_FILES +=		\
	skycalendar.html		\
	skycalendar.js			\
	cycles.plist			\

# make

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
include ../../fhsbundle.make
