# GNUstep makefile

XMLLINT = xmllint
XMLLINT-BIN = $(shell which $(XMLLINT))
ifeq ($(XMLLINT-BIN),)
all ::
	@echo Utility \"$(XMLLINT)\" not found. Skipping validation.
else
all :: validate-wox
endif

WOXS = $(shell find . -name '*.wox' -type f)

validate-wox:
	for wox in $(WOXS); \
	  do $(XMLLINT-BIN) --noout $$wox || exit 1; \
	done;

install :: all

clean ::

distclean :: clean

uninstall ::
