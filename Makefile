# second-hand sourced from https://opensource.com/article/20/3/blog-emacs
# sourced from https://gitlab.com/ngm/commonplace/

# Makefile for myblog


# Make really hates spaces

ORG_FILES := $(shell find "src/org/" -name "*.org")
DOT_FILES := $(patsubst src/org/%.org, src/dot/%.dot, $(ORG_FILES))
SVG_FILES := $(patsubst src/dot/%.dot,res/graph/%.svg,$(DOT_FILES))



$(DOT_FILES): src/dot/%.dot: src/org/%.org
	@echo "Generating dot file for $@"
	@mkdir -p $(dir $@)
	@emacsclient -e "(progn (load \"${PWD}/src/el/graph.el\")\
	 (roam-note-make-dot \"$(patsubst src/dot/%.dot,%.org,$@)\"))"

dot: $(DOT_FILES)

$(SVG_FILES): res/graph/%.svg : src/dot/%.dot
	@echo "Generating svg graphs $@"
	@dot "$(patsubst res/graph/%.svg,src/dot/%.dot,$@)" -Tsvg -o "$@"

svg: $(SVG_FILES)

.PHONY: all publish

init:
	npm install

npm-serve:
	npm run serve

format-scss:
	postcss src/scss/**/*.scss --replace --config package.json

serve: publish npm-serve
serve-new: republish npm-serve

all: republish svg

publish: src/el/publish.el
	@echo "Publishing..."
	emacs --batch --load src/el/publish.el --funcall knowledge/publish

republish: src/el/publish.el
	@echo "Republishing all files..."
	emacs --batch --load src/el/publish.el --funcall knowledge/republish

clean:
	@echo "Cleaning up.."
	@rm -rvf *.elc
	@rm -rvf public
	@rm -rvf ~/.org-timestamps/*
