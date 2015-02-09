all: $(patsubst %.asciidoc,%.pdf,$(wildcard *.asciidoc))

%.pdf : %.asciidoc
	asciidoc -a docinfo1 -b docbook -d book -o $<.docbook $<
	fop -c fonts/fop-config.xml -xsl docbook/xsl/sogo-fo.xsl -xml $<.docbook -pdf $@

clean:
	rm *.asciidoc.docbook *.pdf
