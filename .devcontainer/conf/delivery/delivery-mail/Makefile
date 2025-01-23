export PATH := ./node_modules/.bin:$(PATH)

all: info mail.html

clean:
	rm *.html

info:
	echo "https://mjml.io/"

mail.html: mail.mjml
	mjml --config.minify true -r $< -o $@
