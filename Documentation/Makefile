all: $(patsubst %.asciidoc,%.pdf,$(wildcard *.asciidoc))

%.pdf : %.asciidoc
	asciidoc -a docinfo2 -b docbook -d book -d book -o $<.docbook $<
	fop -c fonts/fop-config.xml -xsl docbook/xsl/sogo-fo.xsl -xml $<.docbook -pdf $@

clean:
	rm *.asciidoc.docbook *.pdf
