# second-hand sourced from https://opensource.com/article/20/3/blog-emacs
# sourced from https://gitlab.com/ngm/commonplace/

# Makefile for myblog

.PHONY: all publish publish_no_init

all: graph republish

graph: publish.el
	@echo "Graphing..."
	emacs --batch --load publish.el --funcall knowledge/build-graph-json
	@chmod 755 graph.svg

publish: publish.el
	@echo "Publishing..."
	emacs --batch --load publish.el --funcall knowledge/publish

republish: publish.el
	@echo "Republishing all files..."
	emacs --batch --load publish.el --funcall knowledge/republish

publish_no_init: publish.el
	@echo "Publishing... with --no-init."
	emacs --batch --no-init --load publish.el --funcall org-publish-all

clean:
	@echo "Cleaning up.."
	@rm -rvf *.elc
	@rm -rvf public
	@rm -rvf ~/.org-timestamps/*
