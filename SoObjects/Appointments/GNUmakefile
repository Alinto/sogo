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
	SOGoAppointmentFolders.m	\
	SOGoFreeBusyObject.m		\
	SOGoUserFolder+Appointments.m	\
	\
	SOGoAptMailNotification.m	\
	SOGoAptMailInvitation.m		\
	SOGoAptMailUpdate.m		\
	SOGoAptMailRemoval.m		\
	SOGoAptMailDeletion.m		\
	SOGoAptMailICalReply.m		\

Appointments_RESOURCE_FILES +=		\
	Version				\
	product.plist			\

Appointments_LANGUAGES = Dutch English French German Italian Spanish

Appointments_LOCALIZED_RESOURCE_FILES = Localizable.strings

Appointments_COMPONENTS +=	\
	SOGoAptMailDutchInvitation.wo	\
	SOGoAptMailDutchICalReply.wo	\
	SOGoAptMailDutchUpdate.wo	\
	SOGoAptMailDutchRemoval.wo	\
	SOGoAptMailDutchDeletion.wo	\
	SOGoAptMailEnglishInvitation.wo	\
	SOGoAptMailEnglishICalReply.wo	\
	SOGoAptMailEnglishUpdate.wo	\
	SOGoAptMailEnglishRemoval.wo	\
	SOGoAptMailEnglishDeletion.wo	\
	SOGoAptMailFrenchInvitation.wo	\
	SOGoAptMailFrenchICalReply.wo	\
	SOGoAptMailFrenchUpdate.wo	\
	SOGoAptMailFrenchRemoval.wo	\
	SOGoAptMailFrenchDeletion.wo	\
	SOGoAptMailGermanInvitation.wo	\
	SOGoAptMailGermanICalReply.wo	\
	SOGoAptMailGermanUpdate.wo	\
	SOGoAptMailGermanRemoval.wo	\
	SOGoAptMailGermanDeletion.wo	\
	SOGoAptMailItalianInvitation.wo \
	SOGoAptMailItalianICalReply.wo  \
	SOGoAptMailItalianUpdate.wo	\
	SOGoAptMailItalianRemoval.wo	\
	SOGoAptMailItalianDeletion.wo   \
	SOGoAptMailSpanishInvitation.wo \
	SOGoAptMailSpanishICalReply.wo  \
	SOGoAptMailSpanishUpdate.wo	\
	SOGoAptMailSpanishRemoval.wo	\
	SOGoAptMailSpanishDeletion.wo   \


ADDITIONAL_INCLUDE_DIRS += -I../../SOPE/
ADDITIONAL_LIB_DIRS += -L../../SOPE/GDLContentStore/obj/

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/wobundle.make
-include GNUmakefile.postamble
