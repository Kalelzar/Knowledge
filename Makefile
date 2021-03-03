# second-hand sourced from https://opensource.com/article/20/3/blog-emacs
# sourced from https://gitlab.com/ngm/commonplace/

# Makefile for myblog

.PHONY: all publish publish_no_init

all: setup graph republish

setup
	@echo "Setting up Publish..."
	cp css/ ../Publish/css -rf
	cp js/ ../Publiss/js -rf

graph: publish.el
	@echo "Graphing..."
	emacs --batch --load publish.el --funcall commonplace/build-graph-json
	@chmod 755 graph.svg

publish: publish.el
	@echo "Publishing..."
	emacs --batch --load publish.el --funcall commonplace/publish

republish: publish.el
	@echo "Republishing all files..."
	emacs --batch --load publish.el --funcall commonplace/republish

publish_no_init: publish.el
	@echo "Publishing... with --no-init."
	emacs --batch --no-init --load publish.el --funcall org-publish-all

clean:
	@echo "Cleaning up.."
	@rm -rvf *.elc
	@rm -rvf public
	@rm -rvf ~/.org-timestamps/*
