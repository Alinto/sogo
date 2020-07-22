# GNUstep makefile

include ../common.make

BUNDLE_NAME = SchedulerUI

SchedulerUI_PRINCIPAL_CLASS = SchedulerUIProduct

SchedulerUI_LANGUAGES = $(SOGO_LANGUAGES)

SchedulerUI_OBJC_FILES =		\
	SchedulerUIProduct.m		\
	NSArray+Scheduler.m		\
	NSDictionary+Scheduler.m	\
					\
	UIxCalMainView.m		\
	UIxCalendarProperties.m		\
	UIxCalendarFolderLinksTemplate.m\
					\
	UIxCalDayTable.m		\
	UIxCalUserRightsEditor.m	\
	UIxCalFolderActions.m		\
					\
	UIxCalView.m			\
	UIxCalDayView.m			\
	UIxCalMulticolumnDayView.m	\
	UIxCalWeekView.m		\
	UIxCalMonthView.m		\
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
	UIxRecurrenceEditor.m		\
	UIxReminderEditor.m

SchedulerUI_RESOURCE_FILES += \
	product.plist	

SchedulerUI_LOCALIZED_RESOURCE_FILES += \
	Localizable.strings

# if SoProduct is fixed to enable localized resources, add this to
# SchedulerUI_LOCALIZED_RESOURCE_FILES instead
SchedulerUI_RESOURCE_FILES +=		\
	cycles.plist			\

# make

ADDITIONAL_INCLUDE_DIRS += -I../../SOPE/
ADDITIONAL_LIB_DIRS += -L../../SOPE/GDLContentStore/obj/
ADDITIONAL_LDFLAGS += -Wl,--rpath,$(SOGO_SYSLIBDIR)/sogo

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
