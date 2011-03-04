# GNUstep makefile

include ../common.make

WOBUNDLE_NAME = Mailer

Mailer_PRINCIPAL_CLASS = SOGoMailerProduct

Mailer_OBJC_FILES += \
	Product.m			\
	\
	SOGoMailManager.m		\
	\
	SOGoDraftObject.m		\
	SOGoMailBaseObject.m		\
	SOGoMailAccounts.m		\
	SOGoMailAccount.m		\
	SOGoMailFolder.m		\
	SOGoMailNamespace.m		\
	SOGoMailObject.m		\
	SOGoMailObject+Draft.m		\
	SOGoSentFolder.m		\
	SOGoDraftsFolder.m		\
	SOGoTrashFolder.m		\
	\
	SOGoMailBodyPart.m		\
	SOGoHTMLMailBodyPart.m		\
	SOGoImageMailBodyPart.m		\
	SOGoMessageMailBodyPart.m	\
	SOGoCalendarMailBodyPart.m	\
	SOGoVCardMailBodyPart.m		\
	\
	SOGoMailForward.m		\
	SOGoMailReply.m			\
	\
	SOGoSieveConverter.m		\
	\
	EOQualifier+MailDAV.m		\
	NSData+Mail.m			\
	NSString+Mail.m			\
	SOGoUser+Mailer.m

Mailer_RESOURCE_FILES += \
	Version		\
	product.plist	\

Mailer_RESOURCE_FILES += \
	SOGoMailBrazilianPortugueseForward.wo \
	SOGoMailBrazilianPortugueseReply.wo \
	SOGoMailCatalanForward.wo \
	SOGoMailCatalanReply.wo \
	SOGoMailCzechForward.wo \
	SOGoMailCzechReply.wo \
	SOGoMailDutchForward.wo \
	SOGoMailDutchReply.wo \
	SOGoMailEnglishForward.wo \
	SOGoMailEnglishReply.wo \
	SOGoMailFrenchForward.wo \
	SOGoMailFrenchReply.wo \
	SOGoMailGermanForward.wo \
	SOGoMailGermanReply.wo \
	SOGoMailHungarianForward.wo \
	SOGoMailHungarianReply.wo \
	SOGoMailItalianForward.wo \
	SOGoMailItalianReply.wo \
	SOGoMailNorwegianForward.wo \
	SOGoMailNorwegianReply.wo \
	SOGoMailPolishForward.wo \
	SOGoMailPolishReply.wo \
	SOGoMailRussianForward.wo \
	SOGoMailRussianReply.wo \
	SOGoMailSpanishForward.wo \
	SOGoMailSpanishReply.wo \
	SOGoMailSwedishForward.wo \
	SOGoMailSwedishReply.wo \
	SOGoMailWelshForward.wo \
	SOGoMailWelshReply.wo


ADDITIONAL_INCLUDE_DIRS += -I../../SOPE/
ADDITIONAL_LIB_DIRS += -L../../SOPE/GDLContentStore/obj/

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/wobundle.make
-include GNUmakefile.postamble
