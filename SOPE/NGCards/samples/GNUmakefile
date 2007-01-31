# GNUstep makefile

-include ../../config.make
include $(GNUSTEP_MAKEFILES)/common.make

TOOL_NAME = vcardtest versittest icalparsetest icalds vcf2xml vcfparsetest ievalrrule

ADDITIONAL_INCLUDE_DIRS += -I../NGCards

vcardtest_OBJC_FILES = unittest.m vcardtest.m CardElement.m CardGroup.m CardVersitRenderer.m NSArray+NGCards.m NSDictionary+NGCards.m
versittest_OBJC_FILES = unittest.m versittest.m CardElement.m CardGroup.m CardVersitRenderer.m NSArray+NGCards.m NSDictionary+NGCards.m NSString+NGCards.m
icalparsetest_OBJC_FILES = icalparsetest.m
icalds_OBJC_FILES        = icalds.m
vcf2xml_OBJC_FILES       = vcf2xml.m
vcfparsetest_OBJC_FILES  = vcfparsetest.m CardElement.m CardGroup.m CardVersitRenderer.m NSArray+NGCards.m NSDictionary+NGCards.m NSString+NGCards.m
ievalrrule_OBJC_FILES    = ievalrrule.m

-include GNUmakefile.preamble
include $(GNUSTEP_MAKEFILES)/tool.make
-include GNUmakefile.postamble
-include fhs.make

CardElement.m: ../NGCards/CardElement.m
	ln -sf ../NGCards/CardElement.m ./

CardGroup.m: ../NGCards/CardGroup.m
	ln -sf ../NGCards/CardGroup.m ./

CardVersitRenderer.m: ../NGCards/CardVersitRenderer.m
	ln -sf ../NGCards/CardVersitRenderer.m ./

NSArray+NGCards.m: ../NGCards/NSArray+NGCards.m
	ln -sf ../NGCards/NSArray+NGCards.m ./

NSDictionary+NGCards.m: ../NGCards/NSDictionary+NGCards.m
	ln -sf ../NGCards/NSDictionary+NGCards.m ./

NSString+NGCards.m: ../NGCards/NSString+NGCards.m
	ln -sf ../NGCards/NSString+NGCards.m ./


distclean clean::
	-rm -f CardElement.m CardGroup.m CardVersitRenderer.m NSArray+NGCards.m NSDictionary+NGCards.m NSString+NGCards.m
