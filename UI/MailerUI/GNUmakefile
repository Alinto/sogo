# GNUstep makefile

include ../common.make

BUNDLE_NAME = MailerUI

MailerUI_PRINCIPAL_CLASS = MailerUIProduct

MailerUI_LANGUAGES = English French

MailerUI_OBJC_FILES += \
	MailerUIProduct.m	\
	\
	UIxMailFormatter.m		\
	UIxSubjectFormatter.m		\
	UIxEnvelopeAddressFormatter.m	\
	WOContext+UIxMailer.m		\
	\
	UIxMailMainFrame.m		\
	\
	UIxMailListView.m		\
	UIxMailView.m			\
	UIxMailPopupView.m		\
	UIxMailMoveToPopUp.m		\
	UIxMailFilterPanel.m		\
	\
	UIxMailAccountActions.m		\
	UIxMailEditor.m			\
	UIxMailEditorAttach.m		\
	UIxMailEditorAction.m		\
	UIxMailReplyAction.m		\
	UIxMailForwardAction.m		\
	UIxMailToSelection.m		\
	UIxMailWindowCloser.m		\
	\
	UIxFilterList.m			\
	\
	UIxMailUserRightsEditor.m
# 	UIxSieveEditor.m

MailerUI_RESOURCE_FILES += \
	Version		\
	product.plist	\
	Toolbars/*.toolbar

MailerUI_LOCALIZED_RESOURCE_FILES += \
	Localizable.strings

# make

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
include ../../fhsbundle.make
