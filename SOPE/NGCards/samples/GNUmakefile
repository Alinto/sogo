# GNUstep makefile

-include ../../../config.make
include $(GNUSTEP_MAKEFILES)/common.make

TOOL_NAME = vcardtest versittest icalparsetest icalds vcf2xml vcfparsetest ievalrrule

ADDITIONAL_INCLUDE_DIRS += -I..

vcardtest_OBJC_FILES = unittest.m vcardtest.m CardElement.m CardGroup.m CardVersitRenderer.m NSArray+NGCards.m NSDictionary+NGCards.m NGCardsSaxHandler.m
versittest_OBJC_FILES = unittest.m versittest.m CardElement.m CardGroup.m CardVersitRenderer.m NSArray+NGCards.m NSDictionary+NGCards.m NSString+NGCards.m NGCardsSaxHandler.m
icalparsetest_OBJC_FILES = icalparsetest.m
icalds_OBJC_FILES        = icalds.m
vcf2xml_OBJC_FILES       = vcf2xml.m
vcfparsetest_OBJC_FILES  = vcfparsetest.m CardElement.m CardGroup.m CardVersitRenderer.m NSArray+NGCards.m NSDictionary+NGCards.m NSString+NGCards.m NGCardsSaxHandler.m
ievalrrule_OBJC_FILES    = ievalrrule.m

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/tool.make
-include GNUmakefile.postamble
-include fhs.make

CardElement.m: ../CardElement.m
	ln -sf ../CardElement.m ./

CardGroup.m: ../CardGroup.m
	ln -sf ../CardGroup.m ./

CardVersitRenderer.m: ../CardVersitRenderer.m
	ln -sf ../CardVersitRenderer.m ./

NSArray+NGCards.m: ../NSArray+NGCards.m
	ln -sf ../NSArray+NGCards.m ./

NSDictionary+NGCards.m: ../NSDictionary+NGCards.m
	ln -sf ../NSDictionary+NGCards.m ./

NSString+NGCards.m: ../NSString+NGCards.m
	ln -sf ../NSString+NGCards.m ./

NGCardsSaxHandler.m: ../NGCardsSaxHandler.m
	ln -sf ../NGCardsSaxHandler.m ./

distclean clean::
	-rm -f CardElement.m CardGroup.m CardVersitRenderer.m NSArray+NGCards.m NSDictionary+NGCards.m NSString+NGCards.m
