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
	SOGoMailFolder.m		\
	SOGoMailObject.m		\
	SOGoDraftObject.m		\
	SOGoMailObject+Draft.m		\
	SOGoSentFolder.m		\
	SOGoDraftsFolder.m		\
	SOGoTrashFolder.m		\
	\
	SOGoMailBodyPart.m		\
	SOGoImageMailBodyPart.m		\
	SOGoMessageMailBodyPart.m	\
	SOGoCalendarMailBodyPart.m	\
	SOGoVCardMailBodyPart.m		\
	\
	SOGoMailForward.m		\
	SOGoMailReply.m			\
	\
	NSData+Mail.m			\
	NSString+Mail.m

Mailer_RESOURCE_FILES += \
	Version		\
	product.plist	\

Mailer_RESOURCE_FILES += \
	SOGoMailEnglishForward.wo \
	SOGoMailFrenchForward.wo \
	SOGoMailGermanForward.wo \
    SOGoMailItalianForward.wo \
	SOGoMailEnglishReply.wo \
	SOGoMailFrenchReply.wo \
	SOGoMailGermanReply.wo \
    SOGoMailItalianReply.wo 


ADDITIONAL_INCLUDE_DIRS += -I../../SOPE/
ADDITIONAL_LIB_DIRS += -L../../SOPE/GDLContentStore/obj/

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/wobundle.make
-include GNUmakefile.postamble
