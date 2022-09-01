(in-package #:kons-9)

;;;; polyhedron ================================================================

(defclass polyhedron (point-cloud)
  ((faces :accessor faces :initarg :faces :initform (make-array 0 :adjustable t :fill-pointer t))
   (face-normals :accessor face-normals :initarg :face-normals :initform (make-array 0 :adjustable t :fill-pointer t))
   (point-normals :accessor point-normals :initarg :point-normals :initform (make-array 0 :adjustable t :fill-pointer t))
   (point-colors :accessor point-colors :initarg :point-colors :initform nil)
   (show-normals :accessor show-normals :initarg :show-normals :initform nil)  ; length or nil
   (point-source-use-face-centers? :accessor point-source-use-face-centers? :initarg :point-source-use-face-centers? :initform nil)))

(defmethod printable-data ((self polyhedron))
  (strcat (call-next-method) (format nil ", ~a faces" (length (faces self)))))

(defmethod initialize-instance :after ((polyh polyhedron) &rest initargs)
  (declare (ignore initargs))
  (compute-face-normals polyh)
  (compute-point-normals polyh))

(defmethod empty-polyhedron ((polyh polyhedron))
  (setf (points polyh) (make-array 0 :adjustable t :fill-pointer t))
  (setf (faces polyh) (make-array 0 :adjustable t :fill-pointer t))
  (setf (face-normals polyh) (make-array 0 :adjustable t :fill-pointer t))
  (setf (point-normals polyh) (make-array 0 :adjustable t :fill-pointer t))
  polyh)

(defmethod set-face-point-lists ((polyh polyhedron) point-lists)
  (empty-polyhedron polyh)
  (let ((i -1))
    (dolist (point-list point-lists)
      (let ((p-refs '()))
        (dolist (p point-list)
          (vector-push-extend p (points polyh))
          (push (incf i) p-refs))
        (vector-push-extend (nreverse p-refs) (faces polyh))))))
  
(defmethod polyhedron-bake ((polyh polyhedron))
  (let ((mtx (transform-matrix (transform polyh))))
    (dotimes (i (length (points polyh)))
      (setf (aref (points polyh) i)
            (transform-point (aref (points polyh) i) mtx))))
  (reset-transform (transform polyh))
  polyh)

(defmethod face-center ((polyh polyhedron) face)
  (p-center (face-points polyh face)))

(defmethod face-centers ((polyh polyhedron))
  (map 'vector #'(lambda (f) (face-center polyh f)) (faces polyh)))

(defun triangle-normal (p0 p1 p2)
  (p-normalize (p-cross (p-from-to p0 p1) (p-from-to p1 p2))))

(defun quad-normal (p0 p1 p2 p3)
  (p-normalize (p-cross (p-from-to p0 p2) (p-from-to p1 p3))))

;; no checking, asssumes well-formed faces
(defmethod face-normal ((polyh polyhedron) face)
  (cond ((< (length face) 3)
         (p! 0 0 0))
        ((= (length face) 3)
         (let ((p0 (aref (points polyh) (elt face 0)))
               (p1 (aref (points polyh) (elt face 1)))
               (p2 (aref (points polyh) (elt face 2))))
           (triangle-normal p0 p1 p2)))
        ((= (length face) 4)
         (let ((p0 (aref (points polyh) (elt face 0)))
               (p1 (aref (points polyh) (elt face 1)))
               (p2 (aref (points polyh) (elt face 2)))
               (p3 (aref (points polyh) (elt face 3))))
           (quad-normal p0 p1 p2 p3)))
        (t
         (let ((center (face-center polyh face))
               (p0 (aref (points polyh) (elt face 0)))
               (p1 (aref (points polyh) (elt face 1))))
           (triangle-normal center p0 p1)))))

(defmethod compute-face-normals ((polyh polyhedron))
  (setf (face-normals polyh)
        (map 'vector #'(lambda (f) (face-normal polyh f)) (faces polyh))))

(defmethod compute-point-normals ((polyh polyhedron))
  (let ((p-normals (make-array (length (points polyh)) :initial-element (p! 0 0 0))))
    (doarray (f face (faces polyh))
      (dolist (pref face)
        (setf (aref p-normals pref)
              (p+ (aref p-normals pref)
                  (aref (face-normals polyh) f)))))
    (setf (point-normals polyh)
          (map 'vector #'p-normalize p-normals))))

(defmethod compute-point-normals-SAV ((polyh polyhedron))
  (setf (point-normals polyh) (make-array (length (points polyh))
                                               :initial-element (p! 0 0 0)
                                               :adjustable t
                                               :fill-pointer t))
  (dotimes (f (length (faces polyh)))
    (dolist (pref (aref (faces polyh) f))
      (setf (aref (point-normals polyh) pref)
            (p+ (aref (point-normals polyh) pref)
                (aref (face-normals polyh) f)))))
  (dotimes (n (length (point-normals polyh)))
    (setf (aref (point-normals polyh) n)
          (p-normalize (aref (point-normals polyh) n)))))

(defmethod face-points ((polyh polyhedron) i)
  (mapcar #'(lambda (pref) (aref (points polyh) pref))
          (aref (faces polyh) i)))

(defmethod face-points ((polyh polyhedron) (face list))
  (mapcar #'(lambda (pref) (aref (points polyh) pref))
          face))

(defmethod reverse-face-normals ((polyh polyhedron))
  (dotimes (i (length (face-normals polyh)))
    (setf (aref (face-normals polyh) i) (p-negate (aref (face-normals polyh) i))))
  polyh)

(defmethod allocate-point-colors ((polyh polyhedron))
  (setf (point-colors polyh) (make-array (length (points polyh))
                                         :initial-element *shading-color*)))
  
(defmethod reset-point-colors ((polyh polyhedron))
  (allocate-point-colors polyh)
  polyh)

(defmethod set-point-colors-by-xyz ((polyh polyhedron) color-fn)
  (allocate-point-colors polyh)
  (doarray (i p (points polyh))
    (setf (aref (point-colors polyh) i) (funcall color-fn p))))

(defmethod set-point-colors-by-point-and-normal ((polyh polyhedron) color-fn)
  (allocate-point-colors polyh)
  (doarray (i p (points polyh))
    (let ((n (aref (point-normals polyh) i)))
      (setf (aref (point-colors polyh) i) (funcall color-fn p n)))))

(defun make-polyhedron (points faces &key (name nil) (mesh-type 'polyhedron))
  (make-instance mesh-type :name name
                           :points points
                           :faces faces))

(defmethod refine-face ((polyh polyhedron) face)
  (let* ((point-lists '())
         (points (face-points polyh face))
         (center (p-center points))
        (face-points (coerce points 'vector))
        (n (length points)))
    (dotimes (i n)
      (push (list (aref face-points i)
                  (p-average (aref face-points i) (aref face-points (mod (1+ i) n)))
                  center
                  (p-average (aref face-points i) (aref face-points (mod (1- i) n))))
            point-lists))
    point-lists))
                
(defmethod refine-mesh ((polyh polyhedron) &optional (levels 1))
  (if (<= levels 0)
      (merge-points polyh)
      (let ((points '())
            (faces '()))
        (dotimes (i (length (faces polyh)))
          (let ((pref (length points))               ;starting point index
                (point-lists (refine-face polyh i))) ;list of point-lists
            (dolist (point-list point-lists)
              (let ((face '()))
                (dolist (point point-list)
                  (push point points)
                  (push pref face)
                  (incf pref))
                (push face faces)))))
        (refine-mesh (make-polyhedron (coerce points 'vector) (coerce faces 'vector)) (1- levels)))))

(defmethod merge-points ((polyh polyhedron))
  (let ((hash (make-hash-table :test 'equal))
        (count -1)
        (new-refs (make-array (length (points polyh)))))
    (doarray (i p (points polyh))
      (let ((j (gethash (point->list p) hash)))
        (if (null j)
            (progn
              (incf count)
              (setf (gethash (point->list p) hash) count)
              (setf (aref new-refs i) count))
            (setf (aref new-refs i) j))))
    (let ((new-points (make-array (1+ (apply #'max (coerce new-refs 'list)))))
          (new-faces (make-array (length (faces polyh)))))
      (doarray (i p (points polyh))
        (setf (aref new-points (aref new-refs i)) p))
      (doarray (i f (faces polyh))
        (setf (aref new-faces i) (mapcar (lambda (ref) (aref new-refs ref)) f)))
      (make-polyhedron new-points new-faces))))

(defun triangle-area (p0 p1 p2)
  (let ((e1 (p-from-to p0 p1))
        (e2 (p-from-to p1 p2)))
    (/ (* (p-mag e1) (p-mag e2) (p-angle-sine e1 e2)) 2)))

;;; only works for triangles
(defmethod face-area ((polyh polyhedron) face)
  (cond ((< (length face) 3)
         0.0)
        ((= (length face) 3)
         (let* ((p0 (aref (points polyh) (elt face 0)))
                (p1 (aref (points polyh) (elt face 1)))
                (p2 (aref (points polyh) (elt face 2))))
           (triangle-area p0 p1 p2)))
        (t
         (error "POLYHEDRON ~a FACE ~a IS NOT A TRIANGLE" polyh face))))

(defun barycentric-point (p0 p1 p2 a b)
  (p+ p0
      (p+ (p* (p-from-to p0 p1) a)
          (p* (p-from-to p0 p2) b))))

(defun generate-face-barycentric-points (p0 p1 p2 num)
  (let ((barycentric-points '()))
    (dotimes (i (round num))
      (let ((a (rand2 0.0 1.0))
            (b (rand2 0.0 1.0)))
        (do () ((<= (+ a b) 1.0))
          (setf a (rand2 0.0 1.0))
          (setf b (rand2 0.0 1.0)))
        (push (barycentric-point p0 p1 p2 a b)
              barycentric-points)))
    barycentric-points))

(defmethod generate-point-cloud ((polyh polyhedron) &optional (density 1.0))
    (when (not (is-triangulated-polyhedron? polyh))
      (error "POLYHEDRON ~a IS NOT TRIANGULATED" polyh))
  (let ((points '()))
    (dotimes (f (length (faces polyh)))
      (let* ((area (face-area polyh (aref (faces polyh) f)))
             (face-points (face-points polyh f))
             (p0 (elt face-points 0))
             (p1 (elt face-points 1))
             (p2 (elt face-points 2))
             (barycentric-points (generate-face-barycentric-points p0 p1 p2 (* area density))))
        (dolist (p barycentric-points)
          (push p points))))
    (make-point-cloud (coerce points 'vector))))

(defun face-triangle-refs (prefs)
  (cond ((< (length prefs) 3)
         '())
        ((= (length prefs) 3)
         (list prefs))
        (t
         (let ((p0 (car prefs)))
           (loop for p1 in (cdr prefs)
                 for p2 in (cddr prefs)
                 collect (list p0 p1 p2))))))
      
(defmethod triangulate-polyhedron ((polyh polyhedron))
  (let ((tri-faces '()))
    (dotimes (f (length (faces polyh)))
      (dolist (tri (face-triangle-refs (aref (faces polyh) f)))
        (push tri tri-faces)))
    (make-polyhedron (points polyh) (coerce tri-faces 'vector))))

(defmethod is-triangulated-polyhedron? ((polyh polyhedron))
  (dotimes (f (length (faces polyh)))
    (when (not (<= (length (aref (faces polyh) f)) 3))
      (return-from is-triangulated-polyhedron? nil)))
  t)

(defun make-tetrahedron (diameter &key (name nil) (mesh-type 'polyhedron))
  (let ((r (* diameter 0.5))
        (-r (* diameter -0.5)))
    (make-polyhedron (vector (p!  r (/     -r (sqrt 6)) (/     -r (sqrt 3)))
                             (p! -r (/     -r (sqrt 6)) (/     -r (sqrt 3)))
                             (p!  0 (/     -r (sqrt 6)) (/ (* 2 r) (sqrt 3)))
                             (p!  0 (/ (* 3 r) (sqrt 6)) 0))
                     (vector '(0 2 1) '(0 3 2) '(1 2 3) '(0 1 3))
                     :name name
                     :mesh-type mesh-type)))

(defun make-box (x-size y-size z-size &key (name nil) (mesh-type 'polyhedron))
  (let ((x (* x-size 0.5))
        (y (* y-size 0.5))
        (z (* z-size 0.5)))
    (make-polyhedron (vector (p! (- x) (- y) (- z))
                             (p!    x  (- y) (- z))
                             (p!    x  (- y)    z)
                             (p! (- x) (- y)    z)
                             (p! (- x)    y  (- z))
                             (p!    x     y  (- z))
                             (p!    x     y     z)
                             (p! (- x)    y     z))
                     (vector '(0 1 2 3) '(0 4 5 1) '(1 5 6 2)
                             '(2 6 7 3) '(3 7 4 0) '(4 7 6 5))
                     :name name
                     :mesh-type mesh-type)))

(defun make-cube (side &key (name nil) (mesh-type 'polyhedron))
  (let ((r (* side 0.5))
        (-r (* side -0.5)))
    (make-polyhedron (vector (p! -r -r -r)
                             (p!  r -r -r)
                             (p!  r -r  r)
                             (p! -r -r  r)
                             (p! -r  r -r)
                             (p!  r  r -r)
                             (p!  r  r  r)
                             (p! -r  r  r))
                     (vector '(0 1 2 3) '(0 4 5 1) '(1 5 6 2)
                             '(2 6 7 3) '(3 7 4 0) '(4 7 6 5))
                     :name name
                     :mesh-type mesh-type)))

(defun make-cut-cube-polyhedron (side &key (name nil) (mesh-type 'polyhedron))
  (let ((r (* side 0.5))
        (-r (* side -0.5))
        (b (* side 0.3)))
    (make-polyhedron (vector (p! -r -r -r)
                             (p!  r -r -r)
                             (p!  r -r  r)
                             (p! -r -r  r)
                             (p! -r  r -r)
                             (p!  r  r -r)
                             (p!  r  r  b)
                             (p!  b  r  r)
                             (p! -r  r  r)
                             (p!  r  b  r))
                     (vector '(1 2 3 0) '(5 6 9 2 1) '(9 7 8 3 2)
                             '(0 4 5 1) '(8 4 0 3) '(8 7 6 5 4) '(6 7 9))
                     :name name
                     :mesh-type mesh-type)))

(defun make-octahedron (diameter &key (name nil) (mesh-type 'polyhedron))
  (let* ((r (abs (/ diameter 2)))
         (-r (- r)))
    (make-polyhedron (vector (p!  r  0  0) 
                             (p! -r  0  0)
                             (p!  0  r  0)
                             (p!  0 -r  0)
                             (p!  0  0  r) 
                             (p!  0  0 -r))
                     (vector '(0 2 4) '(2 0 5) '(3 0 4) '(0 3 5)
                             '(2 1 4) '(1 2 5) '(1 3 4) '(3 1 5))
                     :name name
                     :mesh-type mesh-type)))

(defun make-dodecahedron (diameter &key (name nil) (mesh-type 'polyhedron))
  (let* ((r (/ diameter 4))
         (phi (* 1.61803 r))
         (inv (* 0.6180355 r)))
    (make-polyhedron (vector (p! 0 inv phi)
                             (p! 0 (- inv) phi)
                             (p! 0 (- inv) (- phi))
                             (p! 0 inv (- phi))
                             (p! phi 0 inv)
                             (p! (- phi) 0 inv)
                             (p! (- phi) 0 (- inv))
                             (p! phi 0 (- inv))
                             (p! inv phi 0)
                             (p! (- inv) phi 0)
                             (p! (- inv) (- phi) 0)
                             (p! inv (- phi) 0)
                             (p! r r r)
                             (p! (- r) r r)
                             (p! (- r) (- r) r)
                             (p! r (- r) r)
                             (p! r (- r) (- r))
                             (p! r r (- r))
                             (p! (- r) r (- r))
                             (p! (- r) (- r) (- r)))
                     (vector '(0 1 15 4 12)
                             '(0 12 8 9 13)
                             '(0 13 5 14 1)
                             '(1 14 10 11 15)
                             '(2 3 17 7 16)
                             '(2 16 11 10 19)
                             '(2 19 6 18 3)
                             '(18 9 8 17 3)
                             '(15 11 16 7 4)
                             '(4 7 17 8 12)
                             '(13 9 18 6 5)
                             '(5 6 19 10 14))
                     :name name
                     :mesh-type mesh-type)))

(defun make-icosahedron (diameter &key (name nil) (mesh-type 'polyhedron))
  (let* ((p1 (/ (abs (/ diameter 2)) 1.902076))
         (p2 (* p1 1.618034))
         (-p1 (- p1))
         (-p2 (- p2)))
    (make-polyhedron (vector (p!  p2  p1   0)
                             (p! -p2  p1   0)
                             (p!  p2 -p1   0)
                             (p! -p2 -p1   0)
                             (p!  p1   0  p2)
                             (p!  p1   0 -p2)
                             (p! -p1   0  p2)
                             (p! -p1   0 -p2)
                             (p!   0  p2  p1)
                             (p!   0 -p2  p1)
                             (p!   0  p2 -p1)
                             (p!   0 -p2 -p1))
                     (vector '(0 8 4) '(0 5 10) '(2 4 9) '(2 11 5) '(1 6 8) '(1 10 7)
                             '(3 9 6) '(3 7 11) '(0 10 8) '(1 8 10) '(2 9 11)
                             '(3 11 9) '(4 2 0) '(5 0 2) '(6 1 3) '(7 3 1) '(8 6 4)
                             '(9 4 6) '(10 5 7) '(11 7 5))
                     :name name
                     :mesh-type mesh-type)))

(defun make-cube-sphere (side subdiv-levels &key (name nil) (mesh-type 'polyhedron))
  (let ((polyh (refine-mesh (make-cube side :name name :mesh-type mesh-type) subdiv-levels))
        (radius (/ side 2)))
    (setf (points polyh) (map 'vector (lambda (p) (p-sphericize p radius)) (points polyh)))
    (compute-face-normals polyh)
    (compute-point-normals polyh)
    polyh))
