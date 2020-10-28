# GNUstep makefile

include ../common.make

BUNDLE_NAME = MailerUI

MailerUI_PRINCIPAL_CLASS = MailerUIProduct

MailerUI_LANGUAGES = $(SOGO_LANGUAGES)

MailerUI_OBJC_FILES += \
	MailerUIProduct.m	\
	\
	UIxMailFormatter.m		\
	UIxEnvelopeAddressFormatter.m	\
	WOContext+UIxMailer.m		\
	\
	UIxMailMainFrame.m		\
	\
	UIxMailListActions.m		\
	UIxMailView.m			\
	UIxMailSourceView.m		\
	UIxMailPopupView.m		\
	UIxMailMoveToPopUp.m		\
	\
	UIxMailAccountActions.m		\
	UIxMailFolderActions.m		\
	UIxMailFolderSubscriptions.m	\
	UIxMailActions.m		\
	UIxMailEditor.m			\
	UIxMailWindowCloser.m		\
	\
	UIxMailUserRightsEditor.m	\
	UIxMailUserDelegationEditor.m

MailerUI_RESOURCE_FILES += \
	product.plist

MailerUI_LOCALIZED_RESOURCE_FILES += \
	Localizable.strings

# make

ADDITIONAL_INCLUDE_DIRS += -I../../SOPE/
ADDITIONAL_LIB_DIRS += -L../../SOPE/GDLContentStore/obj/ -L../MailPartViewers/obj/
ADDITIONAL_LDFLAGS += -Wl,--rpath,$(SOGO_SYSLIBDIR)/sogo

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
