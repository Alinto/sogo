# GNUstep makefile

include ../common.make

BUNDLE_NAME = MailPartViewers

MailPartViewers_PRINCIPAL_CLASS = MailPartViewersProduct

MailPartViewers_LANGUAGES = English French German

MailPartViewers_OBJC_FILES += \
	MailPartViewersProduct.m	\
	\
	UIxMailRenderingContext.m	\
	UIxMailSizeFormatter.m		\
	\
	UIxMailPartViewer.m		\
	UIxMailPartTextViewer.m		\
	UIxMailPartHTMLViewer.m		\
	UIxMailPartImageViewer.m	\
	UIxMailPartLinkViewer.m		\
	UIxMailPartMixedViewer.m	\
	UIxMailPartAlternativeViewer.m	\
	UIxMailPartMessageViewer.m	\
	UIxMailPartICalViewer.m		\
	\
	UIxMailPartICalAction.m		\
	\
	UIxKolabPartViewer.m		\
	UIxKolabPartContactViewer.m	\
	UIxKolabPartEventViewer.m	\
	UIxKolabPartTaskViewer.m	\

MailPartViewers_RESOURCE_FILES += \
	Version			\
	product.plist		\

MailPartViewers_LOCALIZED_RESOURCE_FILES += \
	Localizable.strings

# make

ADDITIONAL_INCLUDE_DIRS += -I../../SOPE/sope-gdl1/
ADDITIONAL_LIB_DIRS += -L../../SOPE/sope-gdl1/GDLContentStore/obj/

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
include ../../fhsbundle.make
