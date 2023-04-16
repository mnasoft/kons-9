(in-package :kons-9)

;;;; superquadric =======================================================

(defclass superquadric (uv-mesh procedural-mixin)
  ((diameter :accessor diameter :initarg :diameter :initform 1.0)
   (e1 :accessor e1 :initarg :e1 :initform 0.2)
   (e2 :accessor e2 :initarg :e2 :initform 0.2)))

(def-procedural-input superquadric u-dim)
(def-procedural-input superquadric v-dim)
(def-procedural-input superquadric diameter)
(def-procedural-input superquadric e1)
(def-procedural-input superquadric e2)
(def-procedural-output superquadric points)
(def-procedural-output superquadric faces)

(defmethod compute-procedural-node ((mesh superquadric))
  (allocate-mesh-arrays mesh)
  (setf (uv-point-array mesh) (make-array (list (u-dim mesh) (v-dim mesh))))
  (compute-superquadric-mesh mesh)
  (compute-polyhedron-data mesh)
  mesh)
  
(defmethod compute-superquadric-mesh ((mesh superquadric))
  (with-accessors ((u-dim u-dim) (v-dim v-dim) (d diameter) (e1 e1) (e2 e2))
      mesh
    (let* ((r (/ d 2))
           (u-pi (- (/ 2pi u-dim)))     ;negative so backface cull is correct
           (v-pi (/ pi (1- v-dim))))
      (dotimes (i u-dim)
        (let* ((u (* i u-pi))
               (cu1 (cos u))
               (su1 (sin u))
               (cu (* (expt (abs cu1) e1) (if (< cu1 0) -1 1)))
               (su (* (expt (abs su1) e1) (if (< su1 0) -1 1))))
          (dotimes (j v-dim)
            (let* ((v (- (* j v-pi) pi/2))
                   (cv1 (cos v))
                   (sv1 (sin v))
                   (cv (* (expt (abs cv1) e2) (if (< cv1 0) -1 1)))
                   (sv (* (expt (abs sv1) e2) (if (< sv1 0) -1 1))))
              (setf (aref (uv-point-array mesh) i j)
                    (if (or (= j 0) (= j (1- v-dim))) ;make sure first and last profile points are on y axis
                        (p! 0
                            (* sv r)
                            0)
                        (p! (* cv cu r)
                            (* sv r)
                            (* cv su r)))))))))))

(defmethod make-superquadric (u-dim v-dim diameter e1 e2 &key (name nil))
  (compute-procedural-node
   (make-instance 'superquadric :name name
                                :u-dim u-dim
                                :v-dim v-dim
                                :u-wrap t
                                :v-wrap nil
                                :diameter diameter
                                :e1 e1
                                :e2 e2)))

;;;; gui =======================================================================

(defun superquadric-command-table ()
  (let ((table (make-instance `command-table :title "Create Superquadric")))
    (ct-make-shape :S "Superquadric" (make-superquadric 16 16 2.0 0.2 0.2))
    table))

(register-dynamic-command-table-entry "Create" :S "Create Superquadric Menu"
                                      (lambda () (make-active-command-table (superquadric-command-table)))
                                      (lambda () t))
