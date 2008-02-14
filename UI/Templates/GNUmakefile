# GNUstep makefile

# include ../common.make

XMLLINT = xmllint
XMLLINT-BIN = $(shell which $(XMLLINT))
ifeq ($(XMLLINT-BIN),)
all ::
	@echo Utility \"$(XMLLINT)\" not found. Skipping validation.
else
all :: validate-wox
endif

WOXS = $(shell find . -name '*.wox' -type f)
# TEMPLATE_FILES = $(shell ls *wox)
# TEMPLATE_DIRS = ContactsUI \
		MailPartViewers \
		MailerUI 	\
		MainUI 		\
		PreferencesUI 	\
		SchedulerUI

validate-wox:
	for wox in $(WOXS); \
	  do $(XMLLINT-BIN) --noout $$wox || exit 1; \
	done;

# install ::
# 	mkdir -p ${SOGO_TEMPLATESDIR}
# 	for TEMPLATE in $(TEMPLATE_FILES); do \
# 		cp $$TEMPLATE ${SOGO_TEMPLATESDIR}; \
# 	done;
# 	for TEMPLATEDIR in $(TEMPLATE_DIRS); do \
# 		cp -r $$TEMPLATEDIR ${SOGO_TEMPLATESDIR}; \
# 	done;

install clean ::

distclean :: clean

uninstall ::
