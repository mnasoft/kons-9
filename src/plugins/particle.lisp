(in-package :kons-9)
(declaim (optimize debug))
;;;; range attributes ====================================================

(defgeneric range-value (range)
  )

(defgeneric range-mutate (range factor)
  )

(defmethod range-value ((range number))
  range)

(defclass range-attr ()
  ((mean :accessor mean :initarg :mean :initform 0.0)
   (delta :accessor delta :initarg :delta :initform 1.0)))

(defmethod range-duplicate ((range range-attr))
  (make-instance (type-of range) :mean (mean range) :delta (delta range)))

(defclass range-float (range-attr)
  ()
  (:default-initargs
   :mean 0.0
   :delta 1.0))

(defun range-float (mean delta)
  (make-instance 'range-float :mean mean :delta delta))

(defmethod range-value ((range range-float))
  (rand1 (delta range) (mean range)))

(defmethod range-mutate ((range range-float) factor)
  (range-float (+ (mean range) (* factor (rand1 (delta range))))
               (+ (delta range) (* factor (rand1 (delta range))))))

(defclass range-point (range-attr)
  ()
  (:default-initargs
   :mean (p! 0 0 0)
   :delta (p! 1 1 1)))

(defun range-point (mean delta)
  (make-instance 'range-point :mean mean :delta delta))

(defmethod range-value ((range range-point))
  (p-rand1 (delta range) (mean range)))

(defmethod range-mutate ((range range-point) factor)
  (declare (ignore factor))
  (error "RANGE-MUTATE not implemented for class RANGE-POINT"))

;;;; particle ============================================================

(defclass particle ()
  ((pos :accessor pos :initarg :pos :initform (p! 0 0 0))
   (vel :accessor vel :initarg :vel :initform (p! 0 0 0))
   (is-alive? :accessor is-alive? :initarg :is-alive? :initform t)
   (age :accessor age :initarg :age :initform 0)
   (done-spawn? :accessor done-spawn? :initarg :done-spawn? :initform nil)
   (mutate-spawns? :accessor mutate-spawns? :initarg :mutate-spawns? :initform nil)
   (generation :accessor generation :initarg :generation :initform 1)
   (life-span :accessor life-span :initarg :life-span :initform -1) ; -1 = immortal
   (update-angle :accessor update-angle :initarg :update-angle :initform (range-float 0.0 0))
   (spawn-number-children :accessor spawn-number-children :initarg :spawn-number-children :initform (range-float 2 0))
   (spawn-angle :accessor spawn-angle :initarg :spawn-angle :initform (range-float (/ pi 8) (/ pi 16)))
   (spawn-life-span-factor :accessor spawn-life-span-factor :initarg :spawn-life-span-factor :initform (range-float 1.0 0))
   (spawn-velocity-factor :accessor spawn-velocity-factor :initarg :spawn-velocity-factor :initform (range-float 1.0 0))))

(defmethod copy-particle-data ((dst particle) (src particle))
  (setf (mutate-spawns? dst) (mutate-spawns? src))
  (setf (update-angle dst) (range-duplicate (update-angle src)))
  (setf (spawn-number-children dst) (range-duplicate (spawn-number-children src)))
  (setf (spawn-angle dst) (range-duplicate (spawn-angle src)))
  (setf (spawn-life-span-factor dst) (range-duplicate (spawn-life-span-factor src)))
  (setf (spawn-velocity-factor dst) (range-duplicate (spawn-velocity-factor src)))
  )

(defmethod mutate-particle ((ptcl particle) factor)
  (setf (update-angle ptcl) (range-mutate (update-angle ptcl) factor))
  (setf (spawn-number-children ptcl) (range-mutate (spawn-number-children ptcl) factor))
  (setf (spawn-angle ptcl) (range-mutate (spawn-angle ptcl) factor))
  (setf (spawn-life-span-factor ptcl) (range-mutate (spawn-life-span-factor ptcl) factor))
  (setf (spawn-velocity-factor ptcl) (range-mutate (spawn-velocity-factor ptcl) factor))
  ptcl)

(defmethod update-velocity ((ptcl particle))
  (let* ((vel (vel ptcl))
         (rnd (p-rand))
         (axis (p:normalize (p:cross vel rnd)))
         (mtx (make-axis-rotation-matrix (range-value (update-angle ptcl)) axis))
         (new-vel (transform-point vel mtx)))
    (setf (vel ptcl) new-vel)))

(defmethod update-position ((ptcl particle))
  (setf (pos ptcl)
        (p:+ (pos ptcl)
            (update-velocity ptcl))))

(defmethod update-particle ((ptcl particle))
  (if (or (= -1 (life-span ptcl))
          (< (age ptcl) (life-span ptcl)))
      (progn
        (update-position ptcl)
        (incf (age ptcl)))
      (setf (is-alive? ptcl) nil)))

(defmethod spawn-velocity ((ptcl particle))
  (let* ((vel (vel ptcl))
         (rnd (p-rand))
         (axis (p:normalize (p:cross vel rnd)))
         (mtx (make-axis-rotation-matrix (range-value (spawn-angle ptcl)) axis))
         (new-vel (transform-point vel mtx)))
    (p:scale new-vel (range-value (spawn-velocity-factor ptcl)))))

(defmethod spawn-particle ((ptcl particle))
  (let ((child (make-instance (type-of ptcl)
                              :pos (pos ptcl)
                              :vel (spawn-velocity ptcl)
                              :generation (1+ (generation ptcl))
                              :life-span (* (life-span ptcl)
                                            (range-value (spawn-life-span-factor ptcl))))))
    (copy-particle-data child ptcl)   ;transfer data
    (when (mutate-spawns? ptcl)
        (mutate-particle child 1.0))
    child))

(defmethod do-spawn ((ptcl particle))
  (if (and (not (= -1 (life-span ptcl)))
           (>= (age ptcl) (life-span ptcl))
           (not (done-spawn? ptcl)))
      (progn
        (setf (done-spawn? ptcl) t)
        ;; spawn offspring
        (let ((children '()))
          (dotimes (i (round (range-value (spawn-number-children ptcl))))
              (push (spawn-particle ptcl) children))
          children))
      nil))

;;;; climbing-particle ===================================================

#| TODO -- comment out until we have POLYH-CLOSEST-POINT

(defclass climbing-particle (particle)
  ((support-point-cloud :accessor support-point-cloud :initarg :support-point-cloud :initform nil)))

(defmethod copy-particle-data ((dst climbing-particle) (src climbing-particle))
  (call-next-method)
  (setf (support-point-cloud dst) (support-point-cloud src)))

(defmethod update-position ((ptcl climbing-particle))
  (call-next-method)
  (let* ((pos (source-closest-point (support-point-cloud ptcl) (pos ptcl))))
    (when (not (p:= pos (pos ptcl))) ; avoid duplicate points
      (setf (pos ptcl) pos))))
|#

;;;; dynamic-particle ====================================================

(defclass dynamic-particle (particle)
  ((mass :accessor mass :initarg :mass :initform 1.0)
   (elasticity :accessor elasticity :initarg :elasticity :initform 0.75)
   (friction :accessor friction :initarg :friction :initform 0.75)
   (time-step :accessor time-step :initarg :time-step :initform 1.0) ;0.001)
   (force-fields :accessor force-fields :initarg :force-fields :initform '())
   (do-collisions? :accessor do-collisions? :initarg :do-collisions? :initform nil)
   (collision-padding :accessor collision-padding :initarg :collision-padding :initform 0.0)
   (spawn-mass-factor :accessor spawn-mass-factor :initarg :spawn-mass-factor :initform (range-float 1.0 0))))

(defmethod copy-particle-data ((dst dynamic-particle) (src dynamic-particle))
  (call-next-method)
  (setf (elasticity dst) (elasticity src))
  (setf (friction dst) (friction src))
  (setf (time-step dst) (time-step src))
  (setf (force-fields dst) (force-fields src))
  (setf (do-collisions? dst) (do-collisions? src))
  (setf (collision-padding dst) (collision-padding src))
  (setf (spawn-mass-factor dst) (range-duplicate (spawn-mass-factor src))))

(defmethod update-position ((ptcl dynamic-particle))
  (let* ((p0 (pos ptcl))
         (force (if (force-fields ptcl) ;compute force
                    (reduce #'p:+ (mapcar #'(lambda (field) (field-value field p0 (current-time *scene*)))
                                         (force-fields ptcl)))
                    +origin+))
         (acc (p/ force (mass ptcl)))  ;compute acceleration
         (vel (p+ (vel ptcl) acc))     ;compute velocity
         (pos (p:+ p0 (p:scale vel (time-step ptcl))))) ;compute position
    ;; handle collision
    (when (do-collisions? ptcl)
      (let ((elast (elasticity ptcl))
            (friction (friction ptcl))
            (lo (collision-padding ptcl)))
        (when (< (p:y pos) lo)
          (setf (p:y pos) (+ lo (abs (- lo (p:y pos))))
                (p:x vel) (* friction (p:x vel))
                (p:y vel) (* elast (- (p:y vel)))
                (p:z vel) (* friction (p:z vel))))))
    ;; update state
    (setf (vel ptcl) vel)
    (update-velocity ptcl)              ;do wiggle
    (setf (pos ptcl) pos)))

;;;; particle-system ====================================================

(defclass particle-system (polyhedron animator)
  ((particles :accessor particles :initarg :particles :initform (make-array 0 :adjustable t :fill-pointer t))
   (max-generations :accessor max-generations :initarg :max-generations :initform -1) ; -1 = no maximum
   (point-source-use-live-positions-only :accessor point-source-use-live-positions-only :initarg :point-source-use-live-positions-only :initform nil)
   (draw-live-points-only? :accessor draw-live-points-only? :initarg :draw-live-points-only? :initform t)
   (draw-trails :accessor draw-trails :initarg :draw-trails :initform -1))) ;length, -1 = draw entire trail

(defmethod print-object ((self particle-system) stream)
  (print-unreadable-object (self stream :type t :identity t)
    (format stream "~a, timing = ~a ~a, ~a particles" (name self) (start-time self) (duration self)
            (length (particles self)))))

(defmethod add-force-field ((p-sys particle-system) (field force-field))
  (do-array (i ptcl (particles p-sys))
    (push field (force-fields ptcl)))
  p-sys)

(defmethod mutate-particle-system ((p-sys particle-system) factor)
  (do-array (i ptcl (particles p-sys))
    (mutate-particle ptcl factor))
  p-sys)

(defmethod draw ((p-sys particle-system))
  (when *display-wireframe?*
    (draw-wireframe p-sys))
  (when *display-points?*
    (draw-points p-sys nil)))

;;; TODO -- trail not implemented
(defmethod draw-wireframe ((p-sys particle-system))
  (3d-draw-wireframe-polygons (points p-sys) (faces p-sys) :closed? nil))

(defmethod draw-live-points ((p-sys particle-system) use-point-colors?)
  (declare (ignore use-point-colors?))  ;TODO -- maybe implement later
  (let ((visible-points '()))
    (do-array-if (i ptcl #'is-alive? (particles p-sys))
      (push (pos ptcl) visible-points))
    (3d-draw-points (make-array (length visible-points) :initial-contents visible-points)
                    nil)))

(defmethod draw-points ((p-sys particle-system) use-point-colors?)
  (if (draw-live-points-only? p-sys)
      (draw-live-points p-sys use-point-colors?)
      (call-next-method)))

(defmethod draw-normals ((p-sys particle-system))
  ;; do nothing
  )

(defmethod add-point ((p-sys particle-system) point)
  (vector-push-extend point (points p-sys)))

(defmethod add-face ((p-sys particle-system) list)
  (vector-push-extend list (faces p-sys)))

(defmethod add-particle ((p-sys particle-system) ptcl)
  (vector-push-extend ptcl (particles p-sys))
  (add-point p-sys (pos ptcl))
  (add-face p-sys (list (1- (length (points p-sys))))))

(defmethod update-motion ((p-sys particle-system) parent-absolute-timing)
  (declare (ignore parent-absolute-timing))
  (do-array (i ptcl (particles p-sys))
    (when (or (= -1 (max-generations p-sys))
              (<= (generation ptcl) (max-generations p-sys)))
      (when (is-alive? ptcl)
        (update-particle ptcl)
        ;; current particle pos is first element of face refs
        (push (add-point p-sys (pos ptcl)) (aref (faces p-sys) i)))
      (dolist (child (do-spawn ptcl))
        (add-particle p-sys child)))))

;;;; point-source-protocol =====================================================

(defmethod source-points ((p-sys particle-system))
  (let ((points '()))
    (if (point-source-use-live-positions-only p-sys)
        (do-array-if (i ptcl #'is-alive? (particles p-sys))
          (push (pos ptcl) points))
        (dotimes (i (length (faces p-sys)))
          (let ((curve (reverse (face-points-list p-sys i))))
            (setf points (append curve points))))) ;use all points of face
    (make-array (length points) :initial-contents points)))

(defmethod source-directions ((p-sys particle-system))
  (let ((tangents #()))
    (dotimes (i (length (faces p-sys)))
      (let* ((fp-reversed (reverse (face-points-list p-sys i)))
            (curve (make-array (length fp-reversed) :initial-contents fp-reversed)))
        (setf tangents (concatenate 'vector (curve-tangents-aux curve nil) tangents))))
        ;; (setf tangents (append (curve-tangents-aux curve nil) tangents))))
    tangents))

;;;; curve-source-protocol =====================================================

(defmethod source-curves ((p-sys particle-system))
  (let ((curves '()))
    (dotimes (f (length (faces p-sys)))
      (push (reverse (face-points-array p-sys f)) curves)) ;reverse face points
    (nreverse curves)))

(defmethod source-curves-closed ((p-sys particle-system))
  (make-list (length (faces p-sys)) :initial-element nil)) ;always open

;;;; create particle systems ===================================================

(defun make-particle-system-from-point-source (p-source vel-fn particle-class &rest particle-initargs)
  (apply #'make-particle-system-aux
         (source-points p-source)
         (if vel-fn
             (map 'vector vel-fn (source-directions p-source))
             (source-directions p-source))
         particle-class
         particle-initargs))

(defun make-particle-system-from-point (point num min-vel max-vel particle-class &rest particle-initargs)
  (let ((pnts (make-array num))
        (vels (make-array num)))
    (dotimes (i num)
      (setf (aref pnts i) (p:copy point))
      (setf (aref vels i) (p-rand2 min-vel max-vel)))
    (apply #'make-particle-system-aux
           pnts
           vels
           particle-class
           particle-initargs)))

(defun make-particle-system-aux (points velocities particle-class &rest initargs)
  (let ((p-sys (make-instance 'particle-system)))
    (loop for p across points
          for v across velocities
          do (add-particle p-sys (apply #'make-instance particle-class :pos p :vel v initargs)))
    p-sys))

;;;; gui =======================================================================

(defun single-point-source-selected? ()
  (let ((selected-shapes (selected-shapes (scene *default-scene-view*))))
    (and (= 1 (length selected-shapes))
         (provides-point-source-protocol? (first selected-shapes)))))

(defun make-dynamic-particle-system ()
  (let* ((scene (scene *default-scene-view*))
         (p-source (selected-shape scene))
         (p-sys (make-particle-system p-source
                                      (p! .2 .2 .2) 1 -1 'dynamic-particle
                                      :force-fields (list (make-instance 'constant-force-field
                                                                         :force-vector (p! 0 -.02 0))))))
     (add-motion scene p-sys)
    p-sys))

(defun make-wriggly-particle-system ()
  (let* ((scene (scene *default-scene-view*))
         (p-source (selected-shape scene))
         (p-sys (make-particle-system p-source
                                      (p! .2 .2 .2) 1 -1 'particle
                                      :update-angle (range-float (/ pi 8) (/ pi 16)))))
    (add-motion scene p-sys)
    p-sys))

(defun particle-command-table ()
  (let ((table (make-instance `command-table :title "Create Particle System")))
    (ct-make-shape :D "Dynamic Particles" (when (single-point-source-selected?)
                                            (make-dynamic-particle-system)))
    (ct-make-shape :W "Wriggly Particles" (when (single-point-source-selected?)
                                            (make-wriggly-particle-system)))
    table))

(register-dynamic-command-table-entry
 "Context" :P "Create Particle System"
 (lambda () (make-active-command-table (particle-command-table)))
 #'single-point-source-selected?)
