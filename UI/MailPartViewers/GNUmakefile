# GNUstep makefile

include ../common.make

BUNDLE_NAME = MailPartViewers

MailPartViewers_PRINCIPAL_CLASS = MailPartViewersProduct

MailPartViewers_LANGUAGES = Arabic BrazilianPortuguese Catalan Czech Danish Dutch English Finnish French German Hungarian Icelandic Italian NorwegianBokmal NorwegianNynorsk Polish Russian Slovak SpanishSpain SpanishArgentina Swedish Ukrainian Welsh

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
	UIxMailPartSignedViewer.m	\
	UIxMailPartAlternativeViewer.m	\
	UIxMailPartMessageViewer.m	\
	UIxMailPartICalViewer.m		\
	\
	UIxMailPartICalActions.m

MailPartViewers_RESOURCE_FILES += \
	product.plist		\

MailPartViewers_LOCALIZED_RESOURCE_FILES += \
	Localizable.strings

# make

ADDITIONAL_INCLUDE_DIRS += $(shell xml2-config --cflags)
ADDITIONAL_LIB_DIRS += -L../../SOPE/GDLContentStore/obj/ -L../../SoObjects/Mailer/obj -L../../SoObjects/Appointments/obj
ADDITIONAL_LDFLAGS += -Wl,--rpath,$(SOGO_SYSLIBDIR)/sogo

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/bundle.make
-include GNUmakefile.postamble
