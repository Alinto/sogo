# GNUstep makefile

include ../common.make

WOBUNDLE_NAME = Appointments

Appointments_PRINCIPAL_CLASS = SOGoAppointmentsProduct

Appointments_OBJC_FILES = \
	Product.m			\
	NSArray+Appointments.m		\
	iCalEntityObject+SOGo.m 	\
	iCalEvent+SOGo.m	 	\
	iCalEventChanges+SOGo.m 	\
	iCalPerson+SOGo.m 	\
	\
	SOGoCalendarComponent.m		\
	SOGoAppointmentObject.m		\
	SOGoTaskObject.m		\
	SOGoAppointmentFolder.m		\
	SOGoAppointmentFolders.m	\
	SOGoGroupAppointmentFolder.m	\
	SOGoFreeBusyObject.m		\
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

Appointments_COMPONENTS +=	\
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
    SOGoAptMailItalianUpdate.wo \
    SOGoAptMailItalianRemoval.wo    \
    SOGoAptMailItalianDeletion.wo   \


ADDITIONAL_INCLUDE_DIRS += -I../../SOPE/
ADDITIONAL_LIB_DIRS += -L../../SOPE/GDLContentStore/obj/

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/wobundle.make
-include GNUmakefile.postamble
