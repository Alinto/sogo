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
	SOGoMailEnglishForward.m	\
	SOGoMailFrenchForward.m

Mailer_RESOURCE_FILES += \
	Version		\
	product.plist	\

Mailer_RESOURCE_FILES += \
	SOGoMailEnglishForward.wo \
	SOGoMailFrenchForward.wo

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/wobundle.make
-include GNUmakefile.postamble
include ../../fhsbundle.make
