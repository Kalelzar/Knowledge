# second-hand sourced from https://opensource.com/article/20/3/blog-emacs
# sourced from https://gitlab.com/ngm/commonplace/

# Makefile for myblog


# Make really hates spaces
s+ = $(subst \\ ,+,$1)
+s = $(subst +,\\ ,$1)

ORG_FILES := $(shell find "src/org/" -name "*.org" | sed 's: :\\ :g')
ORG_FILES := $(call s+,$(ORG_FILES))
DOT_FILES := $(subst src/org,src/dot,$(ORG_FILES:.org=.dot))
SVG_FILES := $(subst src/dot,res/graph,$(DOT_FILES:.dot=.svg))



$(call +s,$(DOT_FILES)): $(call +s,$(ORG_FILES))
	@echo "Generating dot file for $@"
	@mkdir -p $(dir $@)
	@emacsclient -e "(progn (load \"${PWD}/src/el/graph.el\")\
	 (roam-note-make-dot \"$(subst src/dot,src/org,${@:.dot=.org})\"))"

dot: $(call +s,$(DOT_FILES))

$(call +s,$(SVG_FILES)): $(call +s,$(DOT_FILES))
	@echo "Generating svg graphs $@"
	dot "$(subst res/graph,src/dot,${@:.svg=.dot})" -Tsvg -o "$@"

svg: $(call +s,$(SVG_FILES))

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
