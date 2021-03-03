(require 'package)

(package-initialize)

;; Uncomment this stuff the first time you run, or if you need to update some packages.
;; Uses versions of these packages for the publish process.
;; Didn't yet figure out a way to use packages already installed.
 ;; (and if this was to move to a CI process, would still be needed there).

;(setq package-archives '(("melpa" . "https://melpa.org/packages/")
;                          ("org" . "http://orgmode.org/elpa/")))

;(package-refresh-contents)

;(package-install 'htmlize)
;(package-install 'org-roam)
;(package-install 's)

(require 'ox-publish)
(require 'ox-html)
(require 'htmlize)
(require 'org-roam)
(require 's)

;; Don't create backup files (those ending with ~) during the publish process.
(setq make-backup-files nil)

;;;;;;;;;;;;;;;;;
;; org-publish ;;
;;;;;;;;;;;;;;;;;

;; standard stuff here.
(setq commonplace/publish-url "localhost:80")
(setq commonplace/project-dir "~/Documents/Knowledge")

(setq commonplace/preamble "
		<div class='flex flex-col sm:flex-row sm:items-center sm:justify-between'>
        <span class='flex flex-row sm:flex-row items-center sm:justify-between'>

                <a href='/home/kalelzar/Documents/Publish/index.html'><img src='/images/home.png' /></a>

                <nav id='site-navigation' class='main-navigation sm:pl-2 ml-5'>
                <div class='menu-main-container'><ul id='primary-menu' class='menu'>
<!-- <li id='menu-item-6884' class='menu-item menu-item-type-custom menu-item-object-custom menu-item-6884'><a href='https://doubleloop.net'>stream</a></li>
<li id='menu-item-6883' class='menu-item menu-item-type-custom menu-item-object-custom menu-item-6883'><a class='active' href='https://commonplace.doubleloop.net'>garden</a></li>
<li id='menu-item-7220' class='menu-item menu-item-type-post_type menu-item-object-page menu-item-7220'><a href='https://doubleloop.net/about/'>about</a></li> -->
</ul></div>                </nav><!-- #site-navigation -->
            </span>

            				    <p class='text-lg w-full hidden sm:block sm:w-1/2 sm:text-right ml-5 sm:ml-0 mr-1'>tech</p>
					</div><!-- .site-branding -->
")
(setq commonplace/postamble "")
(setq commonplace/head-extra "
<link href='https://fonts.googleapis.com/css?family=Nunito:400,700&display=swap' rel='stylesheet'>
<link href='https://unpkg.com/tippy.js@6.2.3/themes/dark.css' rel='stylesheet'>
<link rel='stylesheet' type='text/css' href='/home/kalelzar/Documents/Publish/css/style.css'/>
<script src='https://unpkg.com/@popperjs/core@2'></script>
<script src='https://unpkg.com/vis-network@8.2.0/dist/vis-network.min.js'></script>
<script src='https://unpkg.com/@popperjs/core@2'></script>
<script src='/home/kalelzar/Documents/Publish/js/URI.js'></script>
<script src='/home/kalelzar/Documents/Publish/js/page.js'></script>
<script src='https://unpkg.com/tippy.js@6'></script>")


; see https://vicarie.in/posts/blogging-with-org.html
(defun commonplace/sitemap-format-entry (entry _style project)
  "Return string for each ENTRY in PROJECT."
  (format "@@html:<span class=\"archive-item\"><span class=\"archive-date\">@@ %s @@html:</span>@@ [[file:%s][%s]] @@html:</span>@@"
          (format-time-string "%d %h %Y"
                              (org-publish-find-date entry project))
          entry
          (org-publish-find-title entry project)))

(defun commonplace/configure (project-dir publish-dir)
  (setq commonplace/project-dir project-dir)
  (commonplace/configure-org-publish project-dir publish-dir)

  ;; this is important - otherwise org-roam--org-roam-file-p doesnt work.
  (setq org-roam-directory project-dir)
  (setq org-roam-db-location (concat project-dir "/org-roam.db")))

(defun commonplace/configure-local ()
  (interactive)
  (commonplace/configure "~/Documents/Knowledge" "~/Documents/Publish")
  )

(defun commonplace/publish ()
  (commonplace/configure "~/Documents/Knowledge" "~/Documents/Publish")

  (rassq-delete-all 'html-mode auto-mode-alist)
  (rassq-delete-all 'web-mode auto-mode-alist)
  (fset 'web-mode (symbol-function 'fundamental-mode))
  (call-interactively 'org-publish-all))

;; republish all files, even if no changes made to the page content.
;; (for example, if you want backlinks to be regenerated).
(defun commonplace/republish ()
  (commonplace/configure "~/Documents/Knowledge" "~/Documents/Publish")

	(let ((current-prefix-arg 4))
    (rassq-delete-all 'web-mode auto-mode-alist)
    (fset 'web-mode (symbol-function 'fundamental-mode))
    (call-interactively 'org-publish-all)))

(defun commonplace/publish-gitlab ()
  (commonplace/configure (file-truename ".") "_posts")
  (org-roam-db-build-cache t)

	(let ((current-prefix-arg 4))
    (rassq-delete-all 'web-mode auto-mode-alist)
    (fset 'web-mode (symbol-function 'fundamental-mode))
    (call-interactively 'org-publish-all)))

(defun commonplace/configure-org-publish (project-dir publish-dir)
  (setq org-publish-project-alist
      `(("commonplace"
         :components ("commonplace-notes" "commonplace-static"))
        ("commonplace-notes"
         :base-directory ,project-dir
         :base-extension "org"
         :publishing-directory ,publish-dir
         :publishing-function org-html-publish-to-html
         :recursive t
         :headline-levels 4
         :with-toc nil
         :html-doctype "html5"
         :html-html5-fancy t
         :html-preamble ,commonplace/preamble
         :html-postamble ,commonplace/postamble
         :html-head-include-scripts nil
         :html-head-include-default-style nil
         :html-head-extra ,commonplace/head-extra
         :html-container "section"
         :htmlized-source nil
         :auto-sitemap t
         :exclude "node_modules"
         :sitemap-title "Recent changes"
         :sitemap-sort-files anti-chronologically
         :sitemap-format-entry commonplace/sitemap-format-entry
         :sitemap-filename "recentchanges.org"
         )
        ("commonplace-static"
         :base-directory ,project-dir
         :base-extension "css\\|js\\|png\\|jpg\\|gif\\|svg\\|svg\\|json\\|pdf"
         :publishing-directory ,publish-dir
         :exclude "ltximg"
         :recursive t
         :publishing-function org-publish-attachment))))

(defun commonplace/org-roam-title-to-slug (title)
  "Convert TITLE to a filename-suitable slug.  Use hyphens rather than underscores."
  (cl-flet* ((nonspacing-mark-p (char)
                                (eq 'Mn (get-char-code-property char 'general-category)))
             (strip-nonspacing-marks (s)
                                     (apply #'string (seq-remove #'nonspacing-mark-p
                                                                 (ucs-normalize-NFD-string s))))
             (cl-replace (title pair)
                         (replace-regexp-in-string (car pair) (cdr pair) title)))
    (let* ((pairs `(("[^[:alnum:][:digit:]]" . "-")  ;; convert anything not alphanumeric
                    ("__*" . "-")  ;; remove sequential underscores
                    ("^_" . "")  ;; remove starting underscore
                    ("_$" . "")))  ;; remove ending underscore
           (slug (-reduce-from #'cl-replace (strip-nonspacing-marks title) pairs)))
      (downcase slug))))

(setq org-roam-title-to-slug-function 'commonplace/org-roam-title-to-slug)

;; org-roam backlinks
;; see https://org-roam.readthedocs.io/en/master/org_export/

(defun commonplace/org-roam--backlinks-list (file)
  (if (org-roam--org-roam-file-p file)
      (--reduce-from
       (concat acc (format "- [[file:%s][%s]]\n"
                           (file-relative-name (car it) org-roam-directory)
                           (org-roam-db--get-title (car it))))
       "" (org-roam-db-query [:select [source] :from links :where (= dest $s1)] file))
    ""))

(defun commonplace/org-export-preprocessor (backend)
  (let ((links (commonplace/org-roam--backlinks-list (buffer-file-name))))
    (unless (string= links "")
      (save-excursion
        (goto-char (point-max))
        (insert (concat "\n* Backlinks\n") links)))))

(add-hook 'org-export-before-processing-hook 'commonplace/org-export-preprocessor)

;; Fiddle with the HTML output.
;; TODO: note - a bad idea to override org-html-template!!
;; For now I couldn't figure out another way to hook into the HTML
;; to add the required markup for grid-container, grid, and page.
;; Came across this here: https://github.com/ereslibre/ereslibre.es/blob/b28ea388e2ec09b1033fc7eed2d30c69ba3ee827/config/default.el
;; Perhaps an alternative here?  https://vicarie.in/posts/blogging-with-org.html
(eval-after-load "ox-html"
  '(defun org-html-template (contents info)
     (concat (org-html-doctype info)
             "<html lang=\"en\">
                <head>"
             (org-html--build-meta-info info)
             (org-html--build-head info)
             (org-html--build-mathjax-config info)
             "</head>
                <body>"
             (org-html--build-pre/postamble 'preamble info)
             "<div class='grid-container'><div class='ds-grid'>"
             (unless (string= (org-export-data (plist-get info :title) info) "The Map")
               "<div class='page'>")
             ;; Document contents.
             (let ((div (assq 'content (plist-get info :html-divs))))
               (format "<%s id=\"%s\">\n" (nth 1 div) (nth 2 div)))
             ;; Document title.
             (when (plist-get info :with-title)
               (let ((title (and (plist-get info :with-title)
                                 (plist-get info :title)))
                     (subtitle (plist-get info :subtitle))
                     (html5-fancy (org-html--html5-fancy-p info)))
                 (when title
                   (format
                    (if html5-fancy
                        "<header>\n<h1 class=\"title\">%s</h1> <a class='rooter' href='%s'>*</a>\n%s</header>"
                      "<h1 class=\"title\">%s%s<a class='rooter' href='%s'>*</a></h1>\n")
                    (org-export-data title info)
                    (file-name-nondirectory (plist-get info :output-file))
                    (if subtitle
                        (format
                         (if html5-fancy
                             "<p class=\"subtitle\">%s</p>\n"
                           (concat "\n" (org-html-close-tag "br" nil info) "\n"
                                   "<span class=\"subtitle\">%s</span>\n"))
                         (org-export-data subtitle info))
                      "")))))
             ;; "<script type='text/javascript'>"
             ;; (with-temp-buffer
             ;;   (insert-file-contents "~/Documents/Knowledge/graph.json")
             ;;   (buffer-string))
             ;; "</script>"
             (if (string= (org-export-data (plist-get info :title) info) "The Map")
                 (with-temp-buffer
                   ;(insert-file-contents (concat ,commonplace/project-dir "/graph.svg"))
                   (buffer-string)))
             contents
             (format "</%s>\n" (nth 1 (assq 'content (plist-get info :html-divs))))
             "<div id='temp-network' style='display:none'></div>"
             "</div></div>"
             (unless (string= (org-export-data (plist-get info :title) info) "The Map")
               "</div>")
             (org-html--build-pre/postamble 'postamble info)
             "</body>
              </html>")))

;;;;;;;;;;;;;;;;;;;
;; Graph-related ;;
;;;;;;;;;;;;;;;;;;;

(defvar commonplace/graph-node-extra-config
        '(("shape"      . "rectangle")
          ("style"      . "rounded,filled")
          ("fillcolor"  . "#EEEEEE")
          ("fontname" . "sans")
          ("fontsize" . "10px")
          ("labelfontname" . "sans")
          ("color"      . "#C9C9C9")
          ("fontcolor"  . "#111111")))

;; Change the look of the graphviz graph a little.
(setq org-roam-graph-node-extra-config commonplace/graph-node-extra-config)

(defun commonplace/web-graph-builder (file)
  (concat (url-hexify-string (file-name-sans-extension (file-name-nondirectory file))) ".html"))

;; `org-roam-graph-node-url-builder` is not in master org-roam, I've added it to my local version.
;; see: https://github.com/ngm/org-roam/commit/82f40c122c836684a24a885f044dcc508212a17d
;; It's to allow setting a different URL for nodes on the graph.
(setq org-roam-graph-node-url-builder 'commonplace/web-graph-builder)

(setq org-roam-graph-exclude-matcher '("sitemap" "index" "recentchanges"))

;; Called from the Makefile.
;; It builds the graph and puts graph.dot and graph.svg in a place where I can publish them.
;; I exclude a few extra files from the graph here.
;; (I can't remember why I don't have them in the exclude-matcher!)
(defun commonplace/build-graph ()
  (let* ((node-query `[:select [titles:file titles:title tags:tags] :from titles
                               :left :join tags
                               :on (= titles:file tags:file)])
         (graph      (org-roam-graph--dot node-query))
         (temp-dot (make-temp-file "graph." nil ".dot" graph))
         (temp-graph (make-temp-file "graph." nil ".svg")))
    (call-process "dot" nil 0 nil temp-dot "-Tsvg" "-o" temp-graph)
    (sit-for 5) ; TODO: switch to make-process (async) and callback to not need this.
    (copy-file temp-dot (concat commonplace/project-dir "/graph.dot") 't)
    (copy-file temp-graph (concat commonplace/project-dir "/graph.svg") 't)))


(defun commonplace/external-link-format (text backend info)
  (when (org-export-derived-backend-p backend 'html)
    (when (string-match-p (regexp-quote "http") text)
      (s-replace "<a" "<a target='_blank' rel='noopener noreferrer'" text))))

(add-to-list 'org-export-filter-link-functions
             'commonplace/external-link-format)

(setq org-roam-server-network-label-wrap-length 20)
(setq org-roam-server-network-label-truncate t)
(setq org-roam-server-network-label-truncate-length 60)
(setq org-roam-server-extra-node-options nil)
(setq org-roam-server-extra-edge-options nil)
(setq org-roam-server-network-arrows nil)


(defun commonplace/build-graph-json ()
  (let* ((node-query `[:select [titles:file titles:title tags:tags] :from titles
                               :left :join tags
                               :on (= titles:file tags:file)])
         (temp-graph (make-temp-file "graph." nil ".json")))
    (write-region (commonplace/visjs-json node-query) nil temp-graph)
    ;(sit-for 5) ; TODO: switch to make-process (async) and callback to not need this.
    (copy-file temp-graph (concat commonplace/project-dir "/graph.json") 't)))

(defun commonplace/visjs-json (node-query)
  "Convert `org-roam` NODE-QUERY db query to the visjs json format."
  (org-roam-db--ensure-built)
  (org-roam--with-temp-buffer nil
    (let* ((-compare-fn (lambda (x y) (string= (car x) (car y))))
           (nodes (-distinct (org-roam-db-query node-query)))
           (edges-query
            `[:with selected :as [:select [file] :from ,node-query]
                    :select :distinct [source dest] :from links
                    :where (and (in to selected) (in from selected))])
           (edges-cites-query
            `[:with selected :as [:select [file] :from ,node-query]
                    :select :distinct [file from] :from links
                    :inner :join refs :on (and (= links:dest refs:ref)
                                               (= links:type "cite")
                                               (= refs:type "cite"))
                    :where (and (in file selected) (in from selected))])
           (edges       (org-roam-db-query edges-query))
           (edges-cites (org-roam-db-query edges-cites-query))
           (graph (list (cons 'nodes (list))
                        (cons 'edges (list)))))
      (dotimes (idx (length nodes))
        (let* ((file (xml-escape-string (car (elt nodes idx))))
               (title (or (cadr (elt nodes idx))
                          (org-roam--path-to-slug file)))
               (tags (elt (elt nodes idx) 2)))
          (push (append (list (cons 'id (org-roam--path-to-slug file))
                              (cons 'title title)
                              (cons 'tags tags)
                              (cons 'label (s-word-wrap
                                            org-roam-server-network-label-wrap-length
                                            (if org-roam-server-network-label-truncate
                                                (s-truncate
                                                 org-roam-server-network-label-truncate-length
                                                 title)
                                              title)))
                              (cons 'url (concat "org-protocol://roam-file?file="
                                                 (url-hexify-string file)))
                              (cons 'path file))
                        (pcase org-roam-server-extra-node-options
                          ('nil nil)
                          ((pred functionp)
                           (funcall org-roam-server-extra-node-options (elt nodes idx)))
                          ((pred listp)
                           org-roam-server-extra-node-options)
                          (wrong-type
                           (error "Wrong type of org-roam-server-extra-node-options: %s"
                                  wrong-type))))
                (cdr (elt graph 0)))))
      (dolist (edge edges)
        (let* ((title-source (org-roam--path-to-slug (elt edge 0)))
               (title-target (org-roam--path-to-slug (elt edge 1))))
          (push (remove nil (append (list (cons 'from title-source)
                                          (cons 'to title-target)
                                          (cons 'arrows org-roam-server-network-arrows))
                                    (pcase org-roam-server-extra-edge-options
                                      ('nil nil)
                                      ((pred functionp)
                                       (funcall org-roam-server-extra-edge-options edge))
                                      ((pred listp)
                                       org-roam-server-extra-edge-options)
                                      (wrong-type
                                       (error "Wrong type of org-roam-server-extra-edge-options: %s"
                                              wrong-type)))))
                (cdr (elt graph 1)))))
      (dolist (edge edges-cites)
        (let* ((title-source (org-roam--path-to-slug (elt edge 0)))
               (title-target (org-roam--path-to-slug (elt edge 1))))
          (push (remove nil (list (cons 'from title-source)
                                  (cons 'to title-target)
                                  (cons 'arrows org-roam-server-network-arrows)))
                (cdr (elt graph 1)))))
      (json-encode graph))))