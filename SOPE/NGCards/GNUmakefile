# GNUstep makefile

include ../../config.make
include $(GNUSTEP_MAKEFILES)/common.make
include ./Version

SUBPROJECTS += versitCardsSaxDriver

ifneq ($(frameworks),yes)
LIBRARY_NAME = libNGCards
else
FRAMEWORK_NAME = NGCards
endif

libNGCards_HEADER_FILES_DIR         = .
libNGCards_HEADER_FILES_INSTALL_DIR = /NGCards
libNGCards_INTERFACE_VERSION=$(MAJOR_VERSION).$(MINOR_VERSION)
libNGCards_VERSION=$(MAJOR_VERSION).$(MINOR_VERSION).$(SUBMINOR_VERSION)

libNGCards_HEADER_FILES =  		\
	NSArray+NGCards.h		\
	NSCalendarDate+NGCards.h	\
	NSDictionary+NGCards.h		\
	NSString+NGCards.h		\
	NSCalendarDate+ICal.h		\
	\
	CardElement.h			\
	CardGroup.h			\
	\
	CardVersitRenderer.h		\
	iCalXMLRenderer.h		\
	\
	NGCards.h			\
	iCalAlarm.h			\
	iCalAttachment.h		\
	iCalByDayMask.h			\
	iCalCalendar.h			\
	iCalDataSource.h		\
	iCalDateTime.h			\
	iCalEntityObject.h		\
	iCalEvent.h			\
	iCalEventChanges.h		\
	iCalFreeBusy.h			\
	iCalJournal.h			\
	iCalObject.h			\
	iCalPerson.h			\
	iCalRecurrenceRule.h		\
	iCalRecurrenceCalculator.h	\
	iCalRepeatableEntityObject.h	\
	iCalTimeZone.h			\
	iCalTimeZonePeriod.h		\
	iCalToDo.h			\
	iCalTrigger.h			\
	iCalUTCOffset.h			\
					\
	NSCalendarDate+ICal.h		\
	\
	NGVCard.h			\
	NGVList.h			\
	NGVCardPhoto.h			\
	NGVCardReference.h		\
# 	NGVCardAddress.h		\
# 	NGVCardStrArrayValue.h		\
# 	NGVCardName.h			\
# 	NGVCardOrg.h			\
# 	NGVCardPhone.h			\
	NGCardsSaxHandler.h		\
# 	NGVCardSimpleValue.h		\
# 	NGVCardValue.h			\

#	IcalResponse.h			\

libNGCards_OBJC_FILES =    		\
	NSArray+NGCards.m		\
	NSCalendarDate+NGCards.m	\
	NSDictionary+NGCards.m		\
	NSString+NGCards.m		\
	NSCalendarDate+ICal.m		\
	\
	CardElement.m			\
	CardGroup.m			\
	\
	CardVersitRenderer.m		\
	iCalXMLRenderer.m		\
	\
	iCalAlarm.m			\
	iCalAttachment.m		\
	iCalByDayMask.m			\
	iCalCalendar.m			\
	iCalDailyRecurrenceCalculator.m	\
	iCalDateTime.m			\
	iCalDataSource.m		\
	iCalEntityObject.m		\
	iCalEvent.m			\
	iCalEventChanges.m		\
	iCalFreeBusy.m			\
	iCalJournal.m			\
	iCalMonthlyRecurrenceCalculator.m \
	iCalObject.m			\
	iCalPerson.m			\
	iCalRecurrenceRule.m		\
	iCalRecurrenceCalculator.m	\
	iCalRepeatableEntityObject.m	\
	iCalTimeZone.m			\
	iCalTimeZonePeriod.m		\
	iCalToDo.m			\
	iCalTrigger.m			\
	iCalUTCOffset.m			\
	iCalWeeklyRecurrenceCalculator.m\
	iCalYearlyRecurrenceCalculator.m\
	\
	NGVCard.m			\
	NGVList.m			\
	NGVCardPhoto.m			\
	NGVCardReference.m		\
	NGCardsSaxHandler.m		\
#	IcalElements.m
#	IcalResponse.m

# framework support

NGCards_PCH_FILE     = $(libNGCards_PCH_FILE)
NGCards_HEADER_FILES = $(libNGCards_HEADER_FILES)
NGCards_OBJC_FILES   = $(libNGCards_OBJC_FILES)
NGCards_SUBPROJECTS  = $(libNGCards_SUBPROJECTS)

# building

-include GNUmakefile.preamble
ifneq ($(frameworks),yes)
ifneq ($(FHS_INSTALL_ROOT),)
GNUSTEP_HEADERS=$(DESTDIR)$(FHS_INSTALL_ROOT)/include
endif
GNUSTEP_TARGET_LDIR=sogo
include $(GNUSTEP_MAKEFILES)/library.make
else
include $(GNUSTEP_MAKEFILES)/framework.make
endif
include $(GNUSTEP_MAKEFILES)/aggregate.make
-include GNUmakefile.postamble
