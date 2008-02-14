# GNUstep makefile

include ../common.make

BUNDLE_NAME = MailerUI

MailerUI_PRINCIPAL_CLASS = MailerUIProduct

MailerUI_LANGUAGES = English French German

MailerUI_OBJC_FILES += \
	MailerUIProduct.m	\
	\
	UIxMailFormatter.m		\
	UIxEnvelopeAddressFormatter.m	\
	WOContext+UIxMailer.m		\
	\
	UIxMailMainFrame.m		\
	\
	UIxMailListView.m		\
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
#	UIxMailEditorAction.m		\
#	UIxMailReplyAction.m		\
#	UIxMailForwardAction.m		\
# 	UIxFilterList.m			\
# 	\
# 	UIxSieveEditor.m

MailerUI_RESOURCE_FILES += \
	Version		\
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
