all: $(patsubst %.asciidoc,%.pdf,$(wildcard *.asciidoc))

%.pdf : %.asciidoc
	asciidoc -a docinfo1 -b docbook -d book -o $<.docbook $<
	xsltproc -o $<.fo docbook/xsl/sogo-fo.xsl $<.docbook
	fop -c fonts/fop-config.xml $<.fo -pdf $@

clean:
	rm -f *.asciidoc.fo *.asciidoc.docbook *.pdf
