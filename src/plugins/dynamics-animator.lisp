(in-package :kons-9)

;;;; dynamics-animator =========================================================

(defclass dynamics-animator (shape-animator)
  ((velocity :accessor velocity :initarg :velocity :initform (p! 0 0 0))
   (mass :accessor mass :initarg :mass :initform 1.0)
   (elasticity :accessor elasticity :initarg :elasticity :initform 0.75)
   (friction :accessor friction :initarg :friction :initform 0.75)
   (time-step :accessor time-step :initarg :time-step :initform 1.0)
   (force-fields :accessor force-fields :initarg :force-fields :initform '())
   (do-collisions? :accessor do-collisions? :initarg :do-collisions? :initform t)
   (collision-padding :accessor collision-padding :initarg :collision-padding :initform 0.0)))

(defmethod copy-instance-data :after ((dst dynamics-animator) (src dynamics-animator))
  (setf (velocity dst) (p:copy (velocity src)))
  (setf (mass dst) (mass src))
  (setf (elasticity dst) (elasticity src))
  (setf (friction dst) (friction src))
  (setf (time-step dst) (time-step src))
  (setf (force-fields dst) (copy-list (force-fields src)))
  (setf (do-collisions? dst) (do-collisions? src))
  (setf (collision-padding dst) (collision-padding src))
  dst)

(defmethod update-motion ((anim dynamics-animator) parent-absolute-timing)
  (declare (ignore parent-absolute-timing))
  (if (null (shape anim))
    (error "DYNAMICS-ANIMATOR ~a HAS NO SHAPE.~%" anim)
    (let* ((p0 (offset (translate (transform (shape anim)))))
           (force (if (force-fields anim) ;compute force
                      (reduce #'p:+ (mapcar #'(lambda (field) (field-value field p0
                                                                          (current-time *scene*)))
                                          (force-fields anim)))
                      +origin+))
	   (acc (p/ force (mass anim)))	;compute acceleration
	   (vel (p+ (velocity anim) acc)) ;compute velocity
	   (pos (p:+ p0 (p:scale vel (time-step anim))))) ;compute position

      (when (do-collisions? anim)	; handle collision
	(let ((elast (elasticity anim))
              (friction (friction anim))
	      (lo (collision-padding anim)))
	  (when (< (p:y pos) lo)
	    (setf (p:y pos) (+ lo (abs (- lo (p:y pos))))
	          (p:x vel) (* friction (p:x vel))
                  (p:y vel) (* elast (- (p:y vel)))
                  (p:z vel) (* friction (p:z vel))))))
      ;; update state
      (setf (velocity anim) vel)
      (translate-to (shape anim) pos))))
