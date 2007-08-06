# GNUstep makefile

include ../common.make

BUNDLE_NAME = Mailer

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
	SOGoMailIdentity.m		\
	SOGoUser+Mail.m			\

Mailer_RESOURCE_FILES += \
	Version		\
	product.plist	\

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
include ../../fhsbundle.make
