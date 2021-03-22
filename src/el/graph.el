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
      (format "\"%s\" [label=\"%s\",tooltip=\"%s\",URL=\"/Knowledge/%s.html\",target=\"_parent\"];"
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
     (format "\"%s\" [label=\"%s\",tooltip=\"%s\",URL=\"/Knowledge/%s.html\",target=\"_parent\"];"
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
  (message (format "Generating dot graph for %s" roam-note))
  (f-write-text (export-clusters-as-dot-graph
                 (-cluster-fork (build-cluster (f-base roam-note)))
                 (make-cluster-node-format :fillcolor "#273434"
                                           :color "#b75867"
                                           :fontcolor "#c4c7c7")
                 (make-cluster-edge-format :color "#b75867")
                 (make-cluster-node-format :style "rounded"
                                           :color "#b75867"
                                           :fontcolor "#c4c7c7")
                 (make-cluster-edge-format :dir "back"
                                           :color "#FFFFFF")
                 (make-cluster-graph-format :nodesep 0
                                            :ranksep 0
                                            :rankdir "LR"
                                            :bgcolor "#132020"))
              coding-category-utf-8
              (f-join org-roam-directory
                      "../dot"
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
;;; graph.el ends here
