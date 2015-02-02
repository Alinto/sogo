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
	SOGoMailLabel.m			\
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
	EOQualifier+MailDAV.m		\
	NSData+Mail.m			\
	NSDictionary+Mail.m		\
	NSString+Mail.m			\
	SOGoUser+Mailer.m

Mailer_RESOURCE_FILES += \
	product.plist	\

Mailer_RESOURCE_FILES += \
	SOGoMailArabicForward.wo \
	SOGoMailArabicReply.wo \
	SOGoMailBrazilianPortugueseForward.wo \
	SOGoMailBrazilianPortugueseReply.wo \
	SOGoMailCatalanForward.wo \
	SOGoMailCatalanReply.wo \
	SOGoMailCzechForward.wo \
	SOGoMailCzechReply.wo \
	SOGoMailDanishForward.wo \
	SOGoMailDanishReply.wo \
	SOGoMailDutchForward.wo \
	SOGoMailDutchReply.wo \
	SOGoMailEnglishForward.wo \
	SOGoMailEnglishReply.wo \
	SOGoMailFinnishForward.wo \
	SOGoMailFinnishReply.wo \
	SOGoMailFrenchForward.wo \
	SOGoMailFrenchReply.wo \
	SOGoMailGermanForward.wo \
	SOGoMailGermanReply.wo \
	SOGoMailHungarianForward.wo \
	SOGoMailHungarianReply.wo \
	SOGoMailIcelandicForward.wo \
	SOGoMailIcelandicReply.wo \
	SOGoMailItalianForward.wo \
	SOGoMailItalianReply.wo \
	SOGoMailNorwegianBokmalForward.wo \
	SOGoMailNorwegianBokmalReply.wo \
	SOGoMailNorwegianNynorskForward.wo \
	SOGoMailNorwegianNynorskReply.wo \
	SOGoMailPolishForward.wo \
	SOGoMailPolishReply.wo \
	SOGoMailRussianForward.wo \
	SOGoMailRussianReply.wo \
	SOGoMailSlovakForward.wo \
	SOGoMailSlovakReply.wo \
	SOGoMailSpanishSpainForward.wo \
	SOGoMailSpanishSpainReply.wo \
	SOGoMailSpanishArgentinaForward.wo \
	SOGoMailSpanishArgentinaReply.wo \
	SOGoMailSwedishForward.wo \
	SOGoMailSwedishReply.wo \
	SOGoMailUkrainianForward.wo \
	SOGoMailUkrainianReply.wo \
	SOGoMailWelshForward.wo \
	SOGoMailWelshReply.wo


Mailer_LANGUAGES = Arabic BrazilianPortuguese Catalan Czech Danish Dutch English Finnish French German Hungarian Icelandic Italian NorwegianBokmal NorwegianNynorsk Polish Russian Slovak SpanishSpain SpanishArgentina Swedish Ukrainian Welsh

Mailer_LOCALIZED_RESOURCE_FILES = Localizable.strings

ADDITIONAL_INCLUDE_DIRS += -I../../SOPE/
ADDITIONAL_INCLUDE_DIRS += $(shell xml2-config --cflags)

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/wobundle.make
-include GNUmakefile.postamble
