# GNUstep makefile

include ../common.make

WOBUNDLE_NAME = Mailer

Mailer_PRINCIPAL_CLASS = SOGoMailerProduct

Mailer_OBJC_FILES += \
	Product.m			\
	\
	SOGoMailManager.m		\
	\
	SOGoMailBaseObject.m		\
	SOGoMailAccounts.m		\
	SOGoMailAccount.m		\
	SOGoSharedMailAccount.m		\
	SOGoMailFolder.m		\
	SOGoSharedInboxFolder.m		\
	SOGoMailObject.m		\
	SOGoMailObject+Draft.m		\
	SOGoTrashFolder.m		\
	\
	SOGoMailBodyPart.m		\
	SOGoImageMailBodyPart.m		\
	SOGoMessageMailBodyPart.m	\
	SOGoCalendarMailBodyPart.m	\
	SOGoVCardMailBodyPart.m		\
	\
	SOGoDraftsFolder.m		\
	SOGoDraftObject.m		\
	\
	SOGoMailForward.m		\
	\
	NSData+Mail.m

Mailer_RESOURCE_FILES += \
	Version		\
	product.plist	\

Mailer_RESOURCE_FILES += \
	SOGoMailEnglishForward.wo \
	SOGoMailFrenchForward.wo \
	SOGoMailGermanForward.wo

ADDITIONAL_INCLUDE_DIRS += -I../../SOPE/sope-gdl1/
ADDITIONAL_LIB_DIRS += -L../../SOPE/sope-gdl1/GDLContentStore/obj/

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/wobundle.make
-include GNUmakefile.postamble
include ../../fhsbundle.make
