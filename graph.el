;;; graph.el  -- A short package for generating partial graphs for org-roam
;;; Commentary:
;;; Code:
(require 'org-roam-db)
(require 'dash)
(require 'f)

(defun collect--connections (file depth)
  "Recursively collect the connections of FILE until DEPTH is 0."
  (setq depth (or depth 1))
  (unless (= depth 0)
    (let ((store (-uniq
                  (--map
                   (f-base it)
                   (-flatten
                    (org-roam-db-query [:select dest
                                                :from links
                                                :where (= source $s1)]
                                       (f-join org-roam-directory (concat file ".org"))))
                   ))))
      (--map
       (cons it (collect--connections it (- depth 1)))
       store)
      )))

(defun collect-connections (file &optional depth)
  "Recursively collect the connections of FILE until DEPTH is 0."
  (cons file (collect--connections file depth)))

(defun collect--backlinks (file depth)
  "Recursively collect the backlinks of FILE until DEPTH is 0."
  (setq depth (or depth 1))
  (unless (= depth 0)
    (let ((store  (-difference
                   (-uniq
                    (--map
                     (f-base it)
                     (-flatten
                      (org-roam-db-query [:select source
                                                  :from links
                                                  :where (= dest $s1)]
                                         (f-join org-roam-directory (concat file ".org"))))))
                   exclude-filter)))
      (--map
       (cons it (collect--backlinks it (- depth 1)))
       store))))

(defun collect-backlinks (file &optional depth)
  "Recursively collect the backlinks of FILE until DEPTH is 0."
  (cons file (collect--backlinks file depth)))


(defun make-dot-from-connections (file connections)
  "Make dot FILE from given CONNECTIONS."
  (unless (f-exists? (f-dirname file))
    (f-mkdir (f-dirname file)))
  (let ((backlinks (--map
                    (collect-backlinks it)
                    (-uniq
                     (-flatten
                      connections)))))
    (with-temp-file file
      (insert (format "digraph \"%s\"{\n" (car connections)))
      (insert "rankdir=TB;\n")
      (insert "bgcolor=\"#132020\";\n")
      (insert "node [shape=\"rectangle\",style=\"rounded,filled\",fillcolor=\"#273434\",fontname=\"sans\",fontsize=\"12px\",labelfontname=\"sans\",color=\"#b75867\",fontcolor=\"#c4c7c7\"];\n")
      (insert "edge [color=\"#b75867\"];\n")
      (insert (--reduce
               (concat acc "\n" it)
               (--map
                (format "\"%s\"[label=\"%s\",tooltip=\"%s\",URL=\"../%s.html\",target=\"_parent\"];" it it it it)
                (-uniq
                 (-flatten connections)))))
      (insert "\n")
      (insert (--reduce
               (concat acc "\n" it)
               (build-arrows connections)))
      (insert "\n")
      (insert "edge [dir=\"back\",color=\"#ffffff\"];\n")
      (insert "node [shape=\"oval\",style=\"filled\",fillcolor=\"#273434\",fontname=\"sans\",fontsize=\"12px\",labelfontname=\"sans\",color=\"#b75867\",fontcolor=\"#c4c7c7\"];\n")
      (insert (--reduce
               (concat acc "\n" it)
               (--map
                (format "\"%s\"[label=\"%s\",tooltip=\"%s\",URL=\"../%s.html\",target=\"_parent\"];" it it it it)
                (-difference
                 (-uniq
                  (-flatten backlinks))
                 (-uniq
                  (-flatten connections))))))
      (insert "\n")
      (let ((-compare-fn #'string=))
        (insert (--reduce
               (concat acc "\n" it)
               (-difference
                (-flatten
                 (--map
                  (build-arrows it)
                  backlinks))
                (build-arrows-r connections)))))
      (insert "\n")
      (insert "}"))))

(defun build--arrows (l)
  "Build pairs from L for dot arrows."
  (cond
   ((> (list-length l) 1)
    (let ((x (car l))
          (xs (cdr l)))
      (-flatten
       (-concat
        (--map
         (cons x (car it))
         xs)
        (--map
         (build--arrows it)
         xs)))))))

(defun build-arrows (l)
  "Build dot arrows from L."
  (--map
   (format "\"%s\" -> \"%s\";" (first it) (cdr it))
   (build--arrows l)))

(defun build-arrows-r (l)
  "Build dot arrows from L in reverse."
  (--map
   (format "\"%s\" -> \"%s\";" (cdr it) (first it))
   (build--arrows l)))

(defvar exclude-filter '("recentchanges")
  "Exclude the contents of this list from collection.")

(defun make-all-dot (depth)
  "Make dot files for all org-roam files at DEPTH."
  (interactive "nDepth: ")
  (dolist (file
           (-flatten
            (org-roam-db-query [:select file
                                        :from files])))
    (make-dot-from-connections
     (f-join org-roam-directory "dot/"
             (concat (f-base file)
                     ".dot"))
     (collect-connections (f-base file) depth))))
;;; graph.el ends here
