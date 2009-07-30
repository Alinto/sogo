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
	SOGoHTMLMailBodyPart.m		\
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
	SOGoMailBrazilianPortugueseForward.wo \
	SOGoMailCzechForward.wo \
	SOGoMailDutchForward.wo \
	SOGoMailEnglishForward.wo \
	SOGoMailFrenchForward.wo \
	SOGoMailGermanForward.wo \
	SOGoMailHungarianForward.wo \
	SOGoMailItalianForward.wo \
	SOGoMailSpanishForward.wo \
	SOGoMailWelshForward.wo \
	SOGoMailRussianForward.wo \
	SOGoMailBrazilianPortugueseReply.wo \
	SOGoMailCzechReply.wo \
	SOGoMailRussianReply.wo \
	SOGoMailDutchReply.wo \
	SOGoMailEnglishReply.wo \
	SOGoMailFrenchReply.wo \
	SOGoMailGermanReply.wo \
	SOGoMailHungarianReply.wo \
	SOGoMailItalianReply.wo \
	SOGoMailSpanishReply.wo \
	SOGoMailWelshReply.wo


ADDITIONAL_INCLUDE_DIRS += -I../../SOPE/
ADDITIONAL_LIB_DIRS += -L../../SOPE/GDLContentStore/obj/

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/wobundle.make
-include GNUmakefile.postamble
