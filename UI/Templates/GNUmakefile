# GNUstep makefile

include ../common.make

XMLLINT = xmllint
XMLLINT-BIN = $(shell which $(XMLLINT))
ifeq ($(XMLLINT-BIN),)
all install ::
	@echo Utility \"$(XMLLINT)\" not found. Skipping validation.
else
all install :: validate-wox
endif

WOXS = $(shell find . -name '*.wox' -type f)
TEMPLATE_DIRS = $(shell find . -type d | grep -v .svn)

validate-wox:
	@for wox in $(WOXS); \
	  do $(XMLLINT-BIN) --noout $$wox || exit 1; \
	done;
	@echo "Template files validated"

install ::
	@if [ -L "$(SOGO_TEMPLATESDIR)" ]; then \
	  echo "$(SOGO_TEMPLATESDIR) is a symbolic link (for development?). Installation skipped."; \
	else \
	  if [ ! -d $(SOGO_TEMPLATESDIR) ]; then mkdir -p $(SOGO_TEMPLATESDIR); fi; \
	  for dir in $(TEMPLATE_DIRS); do \
	    if [ ! -d $(SOGO_TEMPLATESDIR)/$$dir ]; then \
	      echo Creating template directory \"$(SOGO_TEMPLATESDIR)/$$dir\"...; \
	      mkdir $(SOGO_TEMPLATESDIR)/$$dir; \
	    fi; \
	  done; \
	  echo Installing template files...; \
	  tar cf - $(WOXS) | ( cd $(SOGO_TEMPLATESDIR); tar xf -) ;\
	fi

check ::

clean ::

distclean :: clean

uninstall ::
	@if [ -L "$(SOGO_TEMPLATESDIR)" ]; then \
	  echo "$(SOGO_TEMPLATESDIR) is a symbolic link (for development?). Uninstallation skipped."; \
	else \
	  rm -rf $(SOGO_TEMPLATESDIR); \
	fi
