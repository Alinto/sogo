# GNUstep makefile

include ../common.make

WOBUNDLE_NAME = Appointments

Appointments_PRINCIPAL_CLASS = SOGoAppointmentsProduct

Appointments_OBJC_FILES = \
	Product.m			\
	NSArray+Appointments.m		\
	iCalEntityObject+SOGo.m 	\
	iCalRepeatableEntityObject+SOGo.m	\
	iCalEvent+SOGo.m	 	\
	iCalEventChanges+SOGo.m 	\
	iCalPerson+SOGo.m	 	\
	iCalToDo+SOGo.m		 	\
	\
	SOGoCalendarComponent.m		\
	SOGoAppointmentObject.m		\
	SOGoTaskObject.m		\
	SOGoComponentOccurence.m	\
	SOGoAppointmentOccurence.m	\
	SOGoTaskOccurence.m		\
	SOGoAppointmentFolder.m		\
	SOGoAppointmentFolderICS.m	\
	SOGoAppointmentFolderObject.m	\
	SOGoAppointmentFolderXML.m	\
	SOGoAppointmentInboxFolder.m	\
	SOGoWebAppointmentFolder.m	\
	SOGoAppointmentFolders.m	\
	SOGoFreeBusyObject.m		\
	SOGoUser+Appointments.m	\
	SOGoUserFolder+Appointments.m	\
	\
	SOGoCalendarProxy.m \
	\
	SOGoAptMailNotification.m	\
	SOGoAptMailInvitation.m		\
	SOGoAptMailDeletion.m		\
	SOGoAptMailICalReply.m		\
	SOGoAptMailUpdate.m		\
	SOGoAptMailReceipt.m		\
	\
	SOGoEMailAlarmsManager.m	\
	\
	MSExchangeFreeBusySOAPRequest.m \
	MSExchangeFreeBusy.m

Appointments_RESOURCE_FILES +=		\
	product.plist			\
	\
	MSExchangeFreeBusySOAPRequest.wo

Appointments_LANGUAGES = BrazilianPortuguese Catalan Czech Danish Dutch English French German Hungarian Icelandic Italian NorwegianBokmal NorwegianNynorsk Polish Russian SpanishSpain SpanishArgentina Swedish Ukrainian Welsh

Appointments_LOCALIZED_RESOURCE_FILES = Localizable.strings

ADDITIONAL_INCLUDE_DIRS += -I../../SOPE/
ADDITIONAL_LIB_DIRS += -L../../SOPE/GDLContentStore/obj/
ADDITIONAL_LDFLAGS += -lcurl

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/wobundle.make
-include GNUmakefile.postamble
