# GNUstep makefile

include ../common.make

WEBSERVER_RESOURCE_FILES = $(shell ls *css *ico *js *gif *png *html *txt 2> /dev/null)

all ::

install ::
	@if [ -L "$(SOGO_WEBSERVERRESOURCESDIR)" ]; then \
	  echo "$(SOGO_WEBSERVERRESOURCESDIR) is a symbolic link (for development?). Installation skipped."; \
	else \
	  mkdir -p $(SOGO_WEBSERVERRESOURCESDIR); \
	  cp $(WEBSERVER_RESOURCE_FILES) $(SOGO_WEBSERVERRESOURCESDIR)/; \
	  cp -r ckeditor $(SOGO_WEBSERVERRESOURCESDIR)/; \
	  rm -rf $(SOGO_WEBSERVERRESOURCESDIR)/ckeditor/_source; \
	fi

check ::

clean ::

distclean :: clean

uninstall ::
	@if [ -L "$(SOGO_WEBSERVERRESOURCESDIR)" ]; then \
	  echo "$(SOGO_WEBSERVERRESOURCESDIR) is a symbolic link (for development?). Uninstallation skipped."; \
	else \
	  rm -rf $(SOGO_WEBSERVERRESOURCESDIR); \
	fi
