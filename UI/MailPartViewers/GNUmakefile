# GNUstep makefile

include ../common.make

BUNDLE_NAME = MailPartViewers

MailPartViewers_PRINCIPAL_CLASS = MailPartViewersProduct

MailPartViewers_LANGUAGES = Arabic BrazilianPortuguese Catalan Czech Danish Dutch English Finnish French German Hungarian Icelandic Italian NorwegianBokmal NorwegianNynorsk Polish Russian Slovak SpanishSpain SpanishArgentina Swedish Ukrainian Welsh

MailPartViewers_OBJC_FILES += \
	MailPartViewersProduct.m	\
	\
	UIxMailRenderingContext.m	\
	UIxMailSizeFormatter.m		\
	\
	UIxMailPartViewer.m		\
	UIxMailPartTextViewer.m		\
	UIxMailPartHTMLViewer.m		\
	UIxMailPartImageViewer.m	\
	UIxMailPartLinkViewer.m		\
	UIxMailPartMixedViewer.m	\
	UIxMailPartSignedViewer.m	\
	UIxMailPartAlternativeViewer.m	\
	UIxMailPartMessageViewer.m	\
	UIxMailPartICalViewer.m		\
	\
	UIxMailPartICalActions.m	\
	../../SoObjects/Mailer/SOGoMailBodyPart.m \
	../../SoObjects/Mailer/SOGoHTMLMailBodyPart.m \
	../../SoObjects/Mailer/SOGoCalendarMailBodyPart.m \
	../../SoObjects/Mailer/SOGoMailAccounts.m \
	../../SoObjects/Mailer/SOGoMailBaseObject.m \
	../../SoObjects/Mailer/SOGoMailAccount.m \
	../../SoObjects/Mailer/SOGoMailNamespace.m \
	../../SoObjects/Mailer/SOGoDraftsFolder.m \
	../../SoObjects/Mailer/SOGoSentFolder.m \
	../../SoObjects/Mailer/SOGoTrashFolder.m \
	../../SoObjects/Mailer/SOGoMailFolder.m \
	../../SoObjects/Mailer/SOGoDraftObject.m \
	../../SoObjects/Mailer/SOGoMailObject.m \
	../../SoObjects/Appointments/SOGoEMailAlarmsManager.m \
	../../SoObjects/Appointments/SOGoAppointmentObject.m \
	../../SoObjects/Appointments/SOGoComponentOccurence.m \
	../../SoObjects/Appointments/SOGoAppointmentOccurence.m \
	../../SoObjects/Appointments/SOGoCalendarComponent.m

MailPartViewers_RESOURCE_FILES += \
	product.plist		\

MailPartViewers_LOCALIZED_RESOURCE_FILES += \
	Localizable.strings

# make

ADDITIONAL_INCLUDE_DIRS += $(shell xml2-config --cflags)
ADDITIONAL_LIB_DIRS += -L../../SOPE/GDLContentStore/obj/

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
