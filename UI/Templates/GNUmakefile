# GNUstep makefile

XMLLINT = $(shell which xmllint)
ifeq ($(XMLLIST),)
  XMLLINT = /bin/true
endif

validate-wox:
	$(XMLLINT) --noout *.wox

all :: validate-wox

install :: all

clean ::

distclean :: clean

uninstall ::
