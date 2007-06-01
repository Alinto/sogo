# GNUstep makefile

include ../common.make

WOBUNDLE_NAME = Appointments

Appointments_PRINCIPAL_CLASS = SOGoAppointmentsProduct

# Appointments_LANGUAGES = English French

Appointments_OBJC_FILES = \
	Product.m			\
	NSArray+Appointments.m		\
	iCalEntityObject+SOGo.m 	\
	\
	SOGoCalendarComponent.m		\
	SOGoAppointmentObject.m		\
	SOGoTaskObject.m		\
	SOGoAppointmentFolder.m		\
	SOGoGroupAppointmentFolder.m	\
	SOGoFreeBusyObject.m		\
	\
	SOGoAptMailNotification.m	\
	SOGoAptMailInvitation.m		\
	SOGoAptMailUpdate.m		\
	SOGoAptMailRemoval.m		\
	SOGoAptMailDeletion.m		\

Appointments_RESOURCE_FILES +=		\
	Version				\
	product.plist			\

Appointments_COMPONENTS +=	\
	SOGoAptMailEnglishInvitation.wo	\
	SOGoAptMailFrenchInvitation.wo	\
	SOGoAptMailEnglishUpdate.wo	\
	SOGoAptMailFrenchUpdate.wo	\
	SOGoAptMailEnglishRemoval.wo	\
	SOGoAptMailFrenchRemoval.wo	\
	SOGoAptMailEnglishDeletion.wo	\
	SOGoAptMailFrenchDeletion.wo	\

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/wobundle.make
-include GNUmakefile.postamble
include ../../fhswobundle.make
