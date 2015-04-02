# GNUstep makefile

include ../common.make

WEBSERVER_RESOURCE_DIRS = css fonts img js

build-static-files:
	@if [ -d bower_components ]; then \
	  bower update --allow-root; \
	else \
	  bower install --allow-root; \
	fi
	grunt build

all :: build-static-files

install ::
	@if [ -L "$(SOGO_WEBSERVERRESOURCESDIR)" ]; then \
	  echo "$(SOGO_WEBSERVERRESOURCESDIR) is a symbolic link (for development?). Installation skipped."; \
	else \
	  mkdir -p $(SOGO_WEBSERVERRESOURCESDIR); \
	  cp -r $(WEBSERVER_RESOURCE_DIRS) $(SOGO_WEBSERVERRESOURCESDIR)/; \
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
