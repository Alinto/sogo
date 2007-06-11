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
	UIxCalDateSelector.m		\
	UIxCalUserRightsEditor.m	\
					\
	UIxComponent+Scheduler.m	\
	UIxCalView.m			\
	UIxCalDayView.m			\
	UIxCalMulticolumnDayView.m	\
	UIxCalWeekView.m		\
	UIxCalMonthView.m		\
	UIxCalMonthViewOld.m		\
	UIxAptTableView.m		\
					\
	UIxCalListingActions.m		\
					\
	UIxAttendeesEditor.m		\
	UIxComponentEditor.m		\
	UIxCalendarSelector.m		\
	UIxAppointmentView.m		\
	UIxAppointmentEditor.m		\
	UIxAppointmentProposal.m	\
	UIxTaskView.m		\
	UIxTaskEditor.m		\
	UIxTaskProposal.m	\
	UIxCalDateLabel.m		\
	UIxDatePicker.m			\
	UIxTimeDateControl.m		\
	UIxCalInlineMonthAptView.m	\
	UIxCalParticipationStatusView.m	\
	UIxCalMonthOverview.m

SchedulerUI_RESOURCE_FILES += \
	Version		\
	product.plist	

SchedulerUI_RESOURCE_FILES += \
	Toolbars/SOGoAppointmentFolder.toolbar \
	Toolbars/SOGoAppointmentObject.toolbar \
	Toolbars/SOGoAppointmentObjectAccept.toolbar \
	Toolbars/SOGoAppointmentObjectDecline.toolbar \
	Toolbars/SOGoAppointmentObjectAcceptOrDecline.toolbar \
	Toolbars/SOGoTaskObject.toolbar \
	Toolbars/SOGoComponentClose.toolbar

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
