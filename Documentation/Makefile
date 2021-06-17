all: pdf html

ASCIIDOCS = $(wildcard SOGo*.asciidoc)
PDFS = $(patsubst %.asciidoc,%.pdf, $(ASCIIDOCS))
HTML = $(patsubst %.asciidoc,%.html, $(ASCIIDOCS))

%.pdf: %.asciidoc asciidoctor-pdf-theme.yml $(wildcard includes/*.asciidoc)
	asciidoctor-pdf \
		-a pdf-fontsdir=fonts \
		-a release_version=`git describe --abbrev=0 --tags | cut -d'-' -f 2` \
		-a release_month=`date +%B` \
		-a pdf-theme=asciidoctor-pdf-theme.yml \
		--trace \
		$<

%.html: %.asciidoc $(wildcard includes/*.asciidoc)
	asciidoctor \
		-D . \
		-a release_version=`git describe --abbrev=0 --tags | cut -d'-' -f 2` \
		-a release_month=`date +%B` \
		-n \
		$<

pdf: $(PDFS)

html: $(HTML)

clean:
	rm -f *.pdf *.html
