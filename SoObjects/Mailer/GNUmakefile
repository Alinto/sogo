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
	SOGoJunkFolder.m		\
	SOGoTemplatesFolder.m		\
	\
	SOGoMailBodyPart.m		\
	SOGoHTMLMailBodyPart.m		\
	SOGoImageMailBodyPart.m		\
	SOGoMessageMailBodyPart.m	\
	SOGoCalendarMailBodyPart.m	\
	SOGoTNEFMailBodyPart.m		\
	SOGoVCardMailBodyPart.m		\
	\
	SOGoMailForward.m		\
	SOGoMailReply.m			\
	\
	EOQualifier+MailDAV.m		\
	NSData+Mail.m			\
	NSData+SMIME.m			\
	NSDictionary+Mail.m		\
	NSString+Mail.m			\
	SOGoUser+Mailer.m

Mailer_RESOURCE_FILES += \
	product.plist	\

Mailer_RESOURCE_FILES += \
	SOGoMailArabicForward.wo \
	SOGoMailArabicReply.wo \
	SOGoMailBosnianForward.wo \
	SOGoMailBosnianReply.wo \
	SOGoMailBrazilianPortugueseForward.wo \
	SOGoMailBrazilianPortugueseReply.wo \
	SOGoMailBulgarianForward.wo \
	SOGoMailBulgarianReply.wo \
	SOGoMailCatalanForward.wo \
	SOGoMailCatalanReply.wo \
	SOGoMailChineseChinaForward.wo \
	SOGoMailChineseChinaReply.wo \
	SOGoMailChineseTaiwanForward.wo \
	SOGoMailChineseTaiwanReply.wo \
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
	SOGoMailGalicianForward.wo \
	SOGoMailGalicianReply.wo \
	SOGoMailCroatianForward.wo \
	SOGoMailCroatianReply.wo \
	SOGoMailGermanForward.wo \
	SOGoMailGermanReply.wo \
	SOGoMailHebrewForward.wo \
	SOGoMailHebrewReply.wo \
	SOGoMailHungarianForward.wo \
	SOGoMailHungarianReply.wo \
	SOGoMailIndonesianForward.wo \
	SOGoMailIndonesianReply.wo \
	SOGoMailIcelandicForward.wo \
	SOGoMailIcelandicReply.wo \
	SOGoMailItalianForward.wo \
	SOGoMailItalianReply.wo \
	SOGoMailJapaneseForward.wo \
	SOGoMailJapaneseReply.wo \
	SOGoMailKazakhForward.wo \
	SOGoMailKazakhReply.wo \
	SOGoMailKoreanForward.wo \
	SOGoMailKoreanReply.wo \
	SOGoMailLatvianForward.wo \
	SOGoMailLatvianReply.wo \
	SOGoMailLithuanianForward.wo \
	SOGoMailLithuanianReply.wo \
	SOGoMailMacedonianForward.wo \
	SOGoMailMacedonianReply.wo \
	SOGoMailMontenegrinForward.wo \
	SOGoMailMontenegrinReply.wo \
	SOGoMailNorwegianBokmalForward.wo \
	SOGoMailNorwegianBokmalReply.wo \
	SOGoMailNorwegianNynorskForward.wo \
	SOGoMailNorwegianNynorskReply.wo \
	SOGoMailPolishForward.wo \
	SOGoMailPolishReply.wo \
	SOGoMailPortugueseForward.wo \
	SOGoMailPortugueseReply.wo \
	SOGoMailRomanianForward.wo \
	SOGoMailRomanianReply.wo \
	SOGoMailRussianForward.wo \
	SOGoMailRussianReply.wo \
	SOGoMailSerbianForward.wo \
	SOGoMailSerbianReply.wo \
	SOGoMailSerbianLatinForward.wo \
	SOGoMailSerbianLatinReply.wo \
	SOGoMailSlovakForward.wo \
	SOGoMailSlovakReply.wo \
	SOGoMailSlovenianForward.wo \
	SOGoMailSlovenianReply.wo \
	SOGoMailSpanishSpainForward.wo \
	SOGoMailSpanishSpainReply.wo \
	SOGoMailSpanishArgentinaForward.wo \
	SOGoMailSpanishArgentinaReply.wo \
	SOGoMailSwedishForward.wo \
	SOGoMailSwedishReply.wo \
	SOGoMailThaiForward.wo \
	SOGoMailThaiReply.wo \
	SOGoMailTurkishTurkeyForward.wo \
	SOGoMailTurkishTurkeyReply.wo \
	SOGoMailUkrainianForward.wo \
	SOGoMailUkrainianReply.wo \
	SOGoMailWelshForward.wo \
	SOGoMailWelshReply.wo \
	SOGoMailBasqueReply.wo \
	SOGoMailBasqueForward.wo

Mailer_LANGUAGES = $(SOGO_LANGUAGES)

Mailer_LOCALIZED_RESOURCE_FILES = Localizable.strings

ADDITIONAL_INCLUDE_DIRS += -I../../SOPE/
ADDITIONAL_INCLUDE_DIRS += $(shell xml2-config --cflags)

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/wobundle.make
-include GNUmakefile.postamble
