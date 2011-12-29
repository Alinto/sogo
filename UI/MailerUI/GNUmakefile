# GNUstep makefile

include ../common.make

BUNDLE_NAME = MailerUI

MailerUI_PRINCIPAL_CLASS = MailerUIProduct

MailerUI_LANGUAGES = BrazilianPortuguese Catalan Czech Danish Dutch English French German Hungarian Icelandic Italian NorwegianBokmal NorwegianNynorsk Polish Russian SpanishSpain SpanishArgentina Swedish Ukrainian Welsh

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
	UIxMailFilterPanel.m		\
	\
	UIxMailAccountActions.m		\
	UIxMailFolderActions.m		\
	UIxMailActions.m		\
	UIxMailEditor.m			\
	UIxMailToSelection.m		\
	UIxMailWindowCloser.m		\
	\
	UIxMailUserRightsEditor.m	\
	UIxMailUserDelegationEditor.m	\
#	UIxMailEditorAction.m		\
#	UIxMailReplyAction.m		\
#	UIxMailForwardAction.m		\
# 	UIxFilterList.m			\

MailerUI_RESOURCE_FILES += \
	product.plist	\
	Toolbars/*.toolbar

MailerUI_LOCALIZED_RESOURCE_FILES += \
	Localizable.strings

# make

ADDITIONAL_INCLUDE_DIRS += -I../../SOPE/
ADDITIONAL_LIB_DIRS += -L../../SOPE/GDLContentStore/obj/

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
