# GNUstep makefile

include ../common.make

BUNDLE_NAME = SchedulerUI

SchedulerUI_PRINCIPAL_CLASS = SchedulerUIProduct

SchedulerUI_LANGUAGES = English French German

SchedulerUI_OBJC_FILES =		\
	SchedulerUIProduct.m		\
	NSArray+Scheduler.m		\
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
	UIxAptTableView.m		\
					\
	UIxCalListingActions.m		\
					\
	UIxAttendeesEditor.m		\
	UIxComponentEditor.m		\
	UIxCalendarSelector.m		\
	UIxAppointmentEditor.m		\
	UIxAppointmentProposal.m	\
	UIxTaskEditor.m		\
	UIxTaskProposal.m	\
	UIxCalDateLabel.m		\
	UIxDatePicker.m			\
	UIxTimeDateControl.m		\
	UIxCalParticipationStatusView.m \
	UIxCalMonthOverview.m	\
	UIxCalMonthViewOld.m

SchedulerUI_RESOURCE_FILES += \
	Version		\
	product.plist	

SchedulerUI_RESOURCE_FILES += \
	Toolbars/SOGoAppointmentFolders.toolbar \
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

ADDITIONAL_INCLUDE_DIRS += -I../../SOPE/
ADDITIONAL_LIB_DIRS += -L../../SOPE/GDLContentStore/obj/

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
include ../../fhsbundle.make
