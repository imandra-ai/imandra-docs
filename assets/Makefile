DEPS := static/docs-styles.css
DEPS += static/jekyll-styles.css
DEPS += static/jekyll-styles-dev.css

.PHONY: all
all: $(DEPS)

%.css: %.less
	npx --package less --package tslib lessc $< > $@

%.css: %.sass
	npx sass -I jekyll-resources/_sass $< > $@

.PHONY: clean
clean:
	rm $(DEPS)
