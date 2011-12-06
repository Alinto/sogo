# GNUstep makefile

include ../common.make

BUNDLE_NAME = SchedulerUI

SchedulerUI_PRINCIPAL_CLASS = SchedulerUIProduct

SchedulerUI_LANGUAGES = BrazilianPortuguese Catalan Czech DanishDenmark Dutch English French German Hungarian Icelandic Italian NorwegianBokmal NorwegianNynorsk Polish Russian SpanishSpain SpanishArgentina Swedish Ukrainian Welsh

SchedulerUI_OBJC_FILES =		\
	SchedulerUIProduct.m		\
	NSArray+Scheduler.m		\
	NSDictionary+Scheduler.m	\
					\
	UIxCalMainView.m		\
	UIxCalendarProperties.m		\
	UIxColorPicker.m		\
					\
	UIxCalFilterPanel.m		\
	UIxCalDayTable.m		\
	UIxCalDateSelector.m		\
	UIxCalUserRightsEditor.m	\
	UIxCalFolderActions.m \
					\
	UIxCalView.m			\
	UIxCalDayView.m			\
	UIxCalMulticolumnDayView.m	\
	UIxCalWeekView.m		\
	UIxCalMonthView.m		\
	UIxAptTableView.m		\
					\
	UIxCalListingActions.m		\
	UIxCalMainActions.m		\
					\
	UIxAttendeesEditor.m		\
	UIxComponentEditor.m		\
	UIxCalendarSelector.m		\
	UIxAppointmentActions.m		\
	UIxAppointmentEditor.m		\
	UIxTaskEditor.m			\
	UIxDatePicker.m			\
	UIxTimeDateControl.m		\
	UIxCalMonthOverview.m		\
	UIxCalMonthViewOld.m		\
	UIxRecurrenceEditor.m		\
	UIxReminderEditor.m		\
	UIxOccurenceDialog.m

SchedulerUI_RESOURCE_FILES += \
	product.plist	

SchedulerUI_RESOURCE_FILES += \
	Toolbars/SOGoAppointmentFolders.toolbar \
	Toolbars/SOGoAppointmentObject.toolbar \
	Toolbars/SOGoAppointmentObjectAccept.toolbar \
	Toolbars/SOGoAppointmentObjectDecline.toolbar \
	Toolbars/SOGoAppointmentObjectAcceptOrDecline.toolbar \
	Toolbars/SOGoTaskObject.toolbar \
	Toolbars/SOGoComponentClose.toolbar \
	Toolbars/SOGoEmpty.toolbar

SchedulerUI_LOCALIZED_RESOURCE_FILES += \
	Localizable.strings

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
