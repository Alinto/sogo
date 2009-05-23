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
	SOGoAptMailDeletion.m		\
	SOGoAptMailICalReply.m		\
	SOGoAptMailUpdate.m		\

Appointments_RESOURCE_FILES +=		\
	Version				\
	product.plist			\

Appointments_LANGUAGES = Dutch English French German Italian Spanish Welsh Russian

Appointments_LOCALIZED_RESOURCE_FILES = Localizable.strings

Appointments_COMPONENTS +=	\
	SOGoAptMailDutchInvitation.wo	\
	SOGoAptMailDutchICalReply.wo	\
	SOGoAptMailDutchDeletion.wo	\
	SOGoAptMailDutchUpdate.wo	\
	SOGoAptMailEnglishInvitation.wo	\
	SOGoAptMailEnglishICalReply.wo	\
	SOGoAptMailEnglishDeletion.wo	\
	SOGoAptMailEnglishUpdate.wo	\
	SOGoAptMailFrenchInvitation.wo	\
	SOGoAptMailFrenchICalReply.wo	\
	SOGoAptMailFrenchDeletion.wo	\
	SOGoAptMailFrenchUpdate.wo	\
	SOGoAptMailGermanInvitation.wo	\
	SOGoAptMailGermanICalReply.wo	\
	SOGoAptMailGermanDeletion.wo	\
	SOGoAptMailGermanUpdate.wo	\
	SOGoAptMailRussianInvitation.wo	\
	SOGoAptMailRussianICalReply.wo	\
	SOGoAptMailRussianDeletion.wo	\
	SOGoAptMailRussianUpdate.wo	\
	SOGoAptMailItalianInvitation.wo \
	SOGoAptMailItalianICalReply.wo  \
	SOGoAptMailItalianDeletion.wo   \
	SOGoAptMailItalianUpdate.wo   \
	SOGoAptMailSpanishInvitation.wo \
	SOGoAptMailSpanishICalReply.wo  \
	SOGoAptMailSpanishDeletion.wo   \
	SOGoAptMailSpanishUpdate.wo   \
	SOGoAptMailWelshInvitation.wo \
	SOGoAptMailWelshICalReply.wo  \
	SOGoAptMailWelshDeletion.wo   \
	SOGoAptMailWelshUpdate.wo 

ADDITIONAL_INCLUDE_DIRS += -I../../SOPE/
ADDITIONAL_LIB_DIRS += -L../../SOPE/GDLContentStore/obj/

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/wobundle.make
-include GNUmakefile.postamble
