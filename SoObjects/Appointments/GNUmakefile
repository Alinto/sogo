# GNUstep makefile

include ../common.make

WOBUNDLE_NAME = Appointments

Appointments_PRINCIPAL_CLASS = SOGoAppointmentsProduct

#	SOGoGroupAppointmentFolder.m	
Appointments_OBJC_FILES = \
	Product.m			\
	NSArray+Appointments.m		\
	iCalEntityObject+SOGo.m 	\
	iCalRepeatableEntityObject+SOGo.m	\
	iCalEvent+SOGo.m	 	\
	iCalEventChanges+SOGo.m 	\
	iCalPerson+SOGo.m 	\
	iCalToDo+SOGo.m		 	\
	\
	SOGoCalendarComponent.m		\
	SOGoAppointmentObject.m		\
	SOGoTaskObject.m		\
	SOGoComponentOccurence.m	\
	SOGoAppointmentOccurence.m	\
	SOGoTaskOccurence.m	\
	SOGoAppointmentFolder.m		\
	SOGoAppointmentInboxFolder.m		\
	SOGoWebAppointmentFolder.m		\
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

Appointments_RESOURCE_FILES +=		\
	Version				\
	product.plist			\

Appointments_LANGUAGES = BrazilianPortuguese Czech Dutch English French German Hungarian Italian Russian Spanish Swedish Welsh

Appointments_LOCALIZED_RESOURCE_FILES = Localizable.strings

ADDITIONAL_INCLUDE_DIRS += -I../../SOPE/
ADDITIONAL_LIB_DIRS += -L../../SOPE/GDLContentStore/obj/

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/wobundle.make
-include GNUmakefile.postamble
