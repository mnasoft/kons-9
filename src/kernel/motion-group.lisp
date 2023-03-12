(in-package :kons-9)

;;;; motion-group ============================================================

(defclass motion-group (motion group-mixin)
  ())

(defmethod printable-data ((self motion-group))
  (strcat (call-next-method) (format nil ", ~a children" (length (children self)))))

(defun make-motion-group (motions &key (name nil))
  (let ((group (make-instance 'motion-group :name name)))
    (dolist (motion motions)
      (add-child group motion))
    group))

(defmethod setup-motion ((group motion-group))
  (when (is-active? group)
    (do-children (child group)
      (setup-motion child))))

(defmethod update-motion ((group motion-group) parent-absolute-timing)
  (when (is-active? group)
    (let ((timing (compute-motion-absolute-timing group parent-absolute-timing)))
      (when (in-time-interval? group timing)
        (do-children (child group)
          (update-motion child timing))))))

(defmethod parallel-order ((group motion-group) &optional (start-time 0.0) (duration 1.0))
  (do-children (child group)
    (set-timing child start-time duration)))

(defmethod sequential-order ((group motion-group) &optional (start-time 0.0) (duration 1.0))
  (when (children group)
    (let ((child-duration (/ duration (length (children group))))
          (child-start start-time))
      (do-children (child group)
        (set-timing child child-start child-duration)
        (incf child-start child-duration)))))

(defmethod random-order ((group motion-group) &optional (min-duration 0.0) (max-duration 1.0))
  (do-children (child group)
    (let* ((child-duration (rand2 min-duration max-duration))
           (child-start (rand2 0 (- 1.0 child-duration))))
      (set-timing child child-start child-duration))))

