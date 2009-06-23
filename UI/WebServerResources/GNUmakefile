# GNUstep makefile

include ../common.make

WEBSERVER_RESOURCE_FILES = $(shell ls *css *ico *js *gif *png *html *txt)

all ::

install ::
	@if [ -L "$(SOGO_WEBSERVERRESOURCESDIR)" ]; then \
	  echo "$(SOGO_WEBSERVERRESOURCESDIR) is a symbolic link (for development?). Installation skipped."; \
	else \
	  mkdir -p $(SOGO_WEBSERVERRESOURCESDIR); \
	  cp $(WEBSERVER_RESOURCE_FILES) $(SOGO_WEBSERVERRESOURCESDIR); \
		cp -r fckeditor $(SOGO_WEBSERVERRESOURCESDIR); \
	fi

clean ::

distclean :: clean

uninstall ::
