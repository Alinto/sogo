# GNUstep makefile

include ../common.make

WEBSERVER_RESOURCE_FILES = $(shell ls *css *ico *js *.jpg *gif *png *html *txt)

all ::

install ::
	@mkdir -p ${SOGO_WEBSERVERRESOURCESDIR}
	@cp $(WEBSERVER_RESOURCE_FILES) ${SOGO_WEBSERVERRESOURCESDIR}

clean ::

distclean :: clean

uninstall ::
