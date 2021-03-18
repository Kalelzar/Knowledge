;;; graph.el  -- A short package for generating partial graphs for org-roam
;;; Commentary:
;;; Code:
(require 'org-roam-db)
(require 'dash)
(require 'f)
(require 'cl-lib)

(cl-defstruct cluster
  "A CLUSTER of nodes. TODO: Elaborate"
  (center-node nil
               :type string
               :documentation "The center node of this cluster.")
  (forward-links nil
                 :type list
                 :documentation "A list of nodes the center node of this cluster points to.")
  (back-links nil
              :type list
              :documentation "A list of nodes that point to the center node of this cluster."))

(cl-defstruct cluster-node-format
  (shape "rectangle" :type string)
  (style "rounded,filled" :type string)
  (fontname "sans" :type string)
  (fontsize "12px" :type string)
  (labelfontname "sans" :type string)
  (color "#AAAAAA" :type string)
  (fillcolor "#FFFFFF" :type string)
  (fontcolor "#000000" :type string))

(defun format-to-dot (format)
  (s-join ","
        (--map
         (s-join "=" it)
         (--filter
          (not (string= (cadr it) "nil"))
          (-partition 2
                      (--map
                       (s-chop-suffix ")" (s-chop-prefix ":" it))
                       (cdr (s-split " " (cl-prin1-to-string format)))))))))


(cl-defstruct cluster-edge-format
  (dir nil :type string)
  (color "#000000" :type string))

(cl-defstruct cluster-graph-format
  (nodesep 1 :type float)
  (ranksep 1 :type float)
  (rankdir "TB" :type string)
  (bgcolor "#FFFFFF" :type string))


(defun -cluster-pair (cluster getter)
  (-zip-fill (cluster-center-node cluster)
             '()
             (funcall getter cluster)))

(defun -cluster-pair-left (cluster)
  (-cluster-pair cluster #'cluster-forward-links))

(defun -cluster-pair-right (cluster)
  (-cluster-pair cluster #'cluster-back-links))

(defun -cluster-format-pairs (pairs)
  (-reduce
   #'s-concat
   (--map
    (format "\"%s\" -> \"%s\";" (car it) (cdr it))
    pairs)))

(defun -cluster-format-forward-nodes (cluster)
  (let ((-compare-fn #'string=))
    (-reduce
     #'s-concat
     (--map
     (format "\"%s\" [label=\"%s\",tooltip=\"%s\",URL=\"../%s.html\",target=\"_parent\"];"
             it it it it)
     (-distinct
     (-concat
      (list (cluster-center-node cluster))
      (cluster-forward-links cluster)))))))

(defun -cluster-format-backward-nodes (cluster)
  (let ((-compare-fn #'string=))
    (-reduce
     #'s-concat
     (--map
     (format "\"%s\" [label=\"%s\",tooltip=\"%s\",URL=\"../%s.html\",target=\"_parent\"];"
             it it it it)
     (-distinct
     (cluster-back-links cluster))))))

(defun export-cluster-as-dot (cluster forward-node-format forward-edge-format
                                      backward-node-format backward-edge-format)
  (unless (cluster-p cluster)
    (error "Expected a cluster."))
  (unless (cluster-node-format-p forward-node-format)
    (error "Expected a node-format."))
  (unless (cluster-edge-format-p forward-edge-format)
    (error "Expected a edge-format."))
  (unless (cluster-node-format-p backward-node-format)
    (error "Expected a node-format."))
  (unless (cluster-edge-format-p backward-edge-format)
    (error "Expected a edge-format."))

  (s-concat
   (format "node [%s];" (format-to-dot forward-node-format))
   (-cluster-format-forward-nodes cluster)
   (format "subgraph \"Forward %s\" {" (cluster-center-node cluster))
   (format "edge [%s];" (format-to-dot forward-edge-format))
   (-cluster-format-pairs
    (-cluster-pair-left cluster))
   "}\n"
   (format "node [%s];" (format-to-dot backward-node-format))
   (-cluster-format-backward-nodes cluster)
   (format "subgraph \"Backward %s\" {" (cluster-center-node cluster))
   (format "edge [%s];" (format-to-dot backward-edge-format))
   (-cluster-format-pairs
    (-cluster-pair-right cluster))
   "}"))

(defun export-clusters-as-dot-graph (clusters
                                     forward-node-format forward-edge-format
                                     backward-node-format backward-edge-format
                                     graph-format)
  (unless (proper-list-p clusters)
    (error "Expected a list."))
  (unless (cluster-node-format-p forward-node-format)
    (error "Expected a node-format."))
  (unless (cluster-edge-format-p forward-edge-format)
    (error "Expected a edge-format."))
  (unless (cluster-node-format-p backward-node-format)
    (error "Expected a node-format."))
  (unless (cluster-edge-format-p backward-edge-format)
    (error "Expected a edge-format."))
  (unless (cluster-graph-format-p graph-format)
    (error "Expected a graph-format."))

  (s-concat
   (format "digraph \"%s\" {" (cluster-center-node (first clusters)))
   (format "graph [%s];" (format-to-dot graph-format))
   (-reduce
    #'concat
    (--map
     (export-cluster-as-dot it
                            forward-node-format
                            forward-edge-format
                            backward-node-format
                            backward-edge-format)
     clusters))
   "}"))


(defun roam-note-make-dot (roam-note)
  (f-write-text (export-clusters-as-dot-graph
                 (-cluster-fork (build-cluster (f-base roam-note)))
                 (make-cluster-node-format :fillcolor "#273434"
                                           :color "#b75867"
                                           :fontcolor "#c4c7c7")
                 (make-cluster-edge-format :color "#b75867")
                 (make-cluster-node-format :style "rounded"
                                           :color "#b75867"
                                           :fontcolor "#c4c7c7")
                 (make-cluster-edge-format :dir "back"m
                                           :color "#FFFFFF")
                 (make-cluster-graph-format :nodesep 0
                                            :ranksep 0
                                            :rankdir "LR"
                                            :bgcolor "#132020"))
              coding-category-utf-8
              (f-join org-roam-directory
                      "dot"
                      (concat (f-base roam-note)
                              ".dot"))))

(defun roam-note-make-dot-all ()
  (interactive)
  (dolist (file (-flatten
                (org-roam-db-query [:select file
                                            :from files])))
    (roam-note-make-dot file)))



(defvar cluster-backlinks-exclude-filter '("recentchanges" "README" "Knowledge Base"))

(defun build-cluster (center-node)
  "Construct a cluster around CENTER_NODE."
  (let* ((forward (-map
                   #'f-base
                   (-flatten
                    (org-roam-db-query [:select dest
                                                :from links
                                                :where (= source $s1)]
                                       (f-join org-roam-directory
                                               (concat center-node ".org")))))))
    (make-cluster
   :forward-links
   forward
   :back-links
   (let ((-compare-fn #'string=))
     (-difference
      (-map
       #'f-base
       (-flatten
        (org-roam-db-query [:select source
                                    :from links
                                    :where (= dest $s1)]
                           (f-join org-roam-directory
                                   (concat center-node ".org")))))
      (-concat
       cluster-backlinks-exclude-filter
       forward)))
   :center-node
   center-node)))

(defun cluster= (cl1 cl2)
  (cond
   ((not (and (cluster-p cl1) (cluster-p cl2))) nil)
   ((not (string= (cluster-center-node cl1)
                 (cluster-center-node cl2))) nil)
   ((not (--all?
         (string= (car it) (cdr it))
         (-zip (cluster-forward-links cl1)
               (cluster-forward-links cl2)))) nil)
   ((not (--all?
         (string= (car it) (cdr it))
         (-zip (cluster-back-links cl1)
               (cluster-back-links cl2)))) nil)
   (t t)))


(defun -cluster-left (cluster)
  (--map
   (build-cluster it)
   (cluster-forward-links cluster)))

(defun -cluster-right (cluster)
  (--map
   (build-cluster it)
   (cluster-back-links cluster)))

(defun -cluster-fork (cluster)
  (let ((-compare-fn #'cluster=))
    (-uniq (-concat
            (list cluster)
            (-cluster-left cluster)
            (-cluster-right cluster)))))






























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
  (unless (<= depth 0)
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

(defun at-depth (graph)
  (if (> (list-length graph) 1)
      (let
          ((head (car graph))
           (tail (cdr graph)))
        (-concat
         (--map
          (cons head (car it))
          tail)
         (-non-nil
          (--map
          (at-depth it)
          tail))))
    nil))

(defun --build-cluster (graph)
(print graph)
(cond
 ((proper-list-p graph)
  (-flatten (--map
   (--build-cluster it)
   graph)))
 ((listp graph) graph)
 (t nil)))


(defun build-clusters (graph)
  (-uniq
   (--map
   (cdr it)
   (--group-by
    (car it)
    (--build-cluster (at-depth graph))))))

(defun format-cluster (cluster)
  (s-join ";"
          (-uniq (--map
           (format "\"%s\" -> \"%s\""
                   (car it)
                   (cdr it))
           cluster))))

(defun format-clusters (clusters &optional prefix)
  (let ((prefix (or prefix "")))
    (--map-indexed
     (format "subgraph %scluster_%i {%s}" prefix it-index (format-cluster it))
     clusters)))

(format-clusters (build-clusters (collect-connections "Chain" 3)) "f")

(defun collect-backlinks-of-connections (connections &optional depth)
  (let ((depth (or depth 1)))
    (-flatten-n 1
                (--map
                 (list (cons it (collect--backlinks it depth)))
                 (-uniq
                  (-flatten connections))))))

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
      (insert "graph [nodesep=\"0.0\", ranksep=\"0.0\"];")
      (insert "rankdir=LR;\n")
      (insert "bgcolor=\"#132020\";\n")
      (insert "node [shape=\"rectangle\",style=\"rounded,filled\",fillcolor=\"#273434\",fontname=\"sans\",fontsize=\"12px\",labelfontname=\"sans\",color=\"#b75867\",fontcolor=\"#c4c7c7\"];\n")
      (insert "edge [color=\"#b75867\"];\n")
      (insert (--reduce
               (concat acc "\n" it)
               (--map
                (if (string= (car connections) it)
                    (format "\"%s\"[label=\"%s\",tooltip=\"%s\",target=\"_parent\"];" it it it)
                    (format "\"%s\"[label=\"%s\",tooltip=\"%s\",URL=\"../%s.html\",target=\"_parent\"];" it it it it))
                (-uniq
                 (-flatten connections)))))
      (insert "\n")
      (insert (--reduce
               (concat acc "\n" it)
               (build-arrows connections)))
      (insert "\n")
      (insert "edge [dir=\"back\",color=\"#ffffff\"];\n")
      (insert "node [shape=\"rectangle\",style=\"rounded\",fillcolor=\"#273434\",fontname=\"sans\",fontsize=\"12px\",labelfontname=\"sans\",color=\"#b75867\",fontcolor=\"#c4c7c7\"];\n")
      (insert (--reduce
               (concat acc "\n" it)
               (--map
                (if (string= (car connections) it)
                    (format "\"%s\"[label=\"%s\",tooltip=\"%s\",target=\"_parent\"];" it it it)
                    (format "\"%s\"[label=\"%s\",tooltip=\"%s\",URL=\"../%s.html\",target=\"_parent\"];" it it it it))
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

(defvar exclud sxiv -b -s f -Se-filter '("recentchanges")
  "Exclude the contents of this list from collection.")

;;; TODO: Use correct background color

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
