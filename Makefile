# second-hand sourced from https://opensource.com/article/20/3/blog-emacs
# sourced from https://gitlab.com/ngm/commonplace/

# Makefile for myblog

.PHONY: all publish



init:
	npm install

npm-serve:
	npm run serve

format-scss:
	postcss src/scss/**/*.scss --replace --config package.json

serve: publish npm-serve
serve-new: republish npm-serve

all: republish

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
