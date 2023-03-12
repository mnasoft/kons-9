(in-package :kons-9)


#|
These demos assume that you have succeeded in loading the system and opening
the graphics window. If you have not, please check the README file.

Make sure you have opened the graphics window by doing:

(in-package :kons-9)
(run)

The PARTICLE-SYSTEM class represents particles which are updated over time.
These can be used to simulate fireworks-type objects or trailing/branching
structures.

PARTICLE-SYSTEM inherits from POLYHEDRON and internally creates polygonal faces
from the trails of its particles. These trails/faces can be used as paths for
SWEEP-MESH creation.

The demos below demonstrate examples of using particle systems.
|#

#|
(Demo 01 particle) particle system from a point ================================

Create 10 particles from a point. The particles split after their life-span of
5 frames.
|#

(format t "  particle-system 01...~%") (finish-output)

(with-clear-scene
  (let ((p-sys (make-particle-system-from-point (p! 0 1 0) 10 (p! -.5 0 -.5) (p! .5 1 .5)
                                                'particle
                                                :life-span 5)))
    (add-shape *scene* p-sys)
    (add-motion *scene* p-sys)))
;;; hold down space key in 3D view to run animation

(update-scene *scene* 20)               ;do update for batch testing

#|
(Demo 02 particle) particle system from a point source =========================

Create particles from a point source (points of a curve). The particles get
their velocities from the curve tangents.
|#

(format t "  particle-system 02...~%") (finish-output)

(with-clear-scene
  (let* ((shape (make-circle-curve 2 16))
         (p-sys (make-particle-system-from-point-source shape
                                                        nil
                                                        'particle
                                                        :life-span 5)))
    (add-shape *scene* shape)
    (add-shape *scene* p-sys)
    (add-motion *scene* p-sys)))
;;; hold down space key in 3D view to run animation

(update-scene *scene* 20)               ;do update for batch testing

#|
(Demo 03 particle) particle system from a point source, custom velocities ======

Provide function to modify particle initial velocities.
|#

(format t "  particle-system 03...~%") (finish-output)

(with-clear-scene
  (let ((p-sys (make-particle-system-from-point-source (make-circle-curve 2 16)
                                                       (lambda (v) (p:normalize (p+ v (p! 0 2 0))))
                                                       'particle
                                                       :life-span 5)))
    (add-shape *scene* p-sys)
    (add-motion *scene* p-sys)))
;;; hold down space key in 3D view to run animation

(update-scene *scene* 20)               ;do update for batch testing

#|
(Demo 04 particle) particle system with wriggle ================================

Randomized particle velocities' update-angle to give "wriggle" effect.
|#

(format t "  particle-system 04...~%") (finish-output)

(with-clear-scene
  (let* ((shape (make-icosahedron 2))
         (p-sys (make-particle-system-from-point-source shape
                                                        (lambda (v) (p:scale v 0.2))
                                                        'particle
                                                        :life-span 10
                                                        :update-angle (range-float (/ pi 8) (/ pi 16)))))
    (add-shape *scene* shape)
    (add-shape *scene* p-sys)
    (add-motion *scene* p-sys)))
;;; hold down space key in 3D view to run animation

(update-scene *scene* 20)               ;do update for batch testing

#|
(Demo 05 particle) dynamic particle system with force field ====================

Create dynamic particles with constant force field simulating gravity. Do
collisions with ground plane.
|#

(format t "  particle-system 05...~%") (finish-output)

(with-clear-scene
  (let ((p-sys (make-particle-system-from-point (p! 0 1 0) 10 (p! -.2 0 -.2) (p! .2 .5 .2)
                                                'dynamic-particle
                                                :life-span 20
                                                :do-collisions? t
                                                :elasticity 0.8
                                                :force-fields (list (make-instance 'constant-force-field
                                                                                   :force-vector (p! 0 -.02 0))))))
    (add-shape *scene* p-sys)
    (add-motion *scene* p-sys)))
;;; hold down space key in 3D view to run animation

(update-scene *scene* 100)               ;do update for batch testing

#|
(Demo 06 particle) dynamic particle system with wriggle ========================

Create dynamic particles with wriggle effect.
|#

(format t "  particle-system 06...~%") (finish-output)

(with-clear-scene
  (let ((p-sys (make-particle-system-from-point (p! 0 1 0) 10 (p! -.2 0 -.2) (p! .2 .5 .2)
                                                'dynamic-particle
                                                :life-span 20
                                                :update-angle (range-float (/ pi 8) (/ pi 16))
                                                :do-collisions? t
                                                :elasticity 0.95
                                                :force-fields (list (make-instance 'constant-force-field
                                                                                   :force-vector (p! 0 -.05 0))))))
    (add-shape *scene* p-sys)
    (add-motion *scene* p-sys)))
;;; hold down space key in 3D view to run animation

(update-scene *scene* 100)               ;do update for batch testing

#|
(Demo 07 particle) dynamic particle system with an attractor force field =======

Simulate particles in orbit.
|#

(format t "  particle-system 07...~%") (finish-output)

(with-clear-scene
  (let ((p-sys (make-particle-system-from-point-source (make-circle-curve 4 16)
                                                       (lambda (v) (p:scale (p:normalize (p+ v (p-rand))) 0.2))
                                                       'dynamic-particle
                                                       :life-span -1 ;infinite life-span
                                                       :do-collisions? nil
                                                       :force-fields (list (make-instance 'attractor-force-field
                                                                                          :location (p! 0 0 0)
                                                                                          :magnitude 0.1)))))
    (add-shape *scene* p-sys)
    (add-motion *scene* p-sys)))
;;; hold down space key in 3D view to run animation

(update-scene *scene* 100)               ;do update for batch testing

#|
(Demo 08 particle) dynamic particle system with a noise force field ============

Dynamic particles growing from a height field under the influence of a noise
force field.
|#

(format t "  particle-system 08...~%") (finish-output)

(with-clear-scene
  (let* ((shape (freeze-transform (translate-by (make-heightfield 20 20 (p! -5 0 -5) (p! 5 0 5)
                                                                  :height-fn (lambda (x z)
                                                                               (* 4 (turbulence (p! x 0 z) 4))))
                                                (p! 0 -1 0))))
         (p-sys (make-particle-system-from-point-source shape
                                                        (lambda (v) (p:scale v 0.05))
                                                        'dynamic-particle
                                                        :life-span -1 ;infinite life-span
                                                        :do-collisions? nil
                                                        :force-fields (list (make-instance 'noise-force-field
                                                                                           :noise-frequency 0.2
                                                                                           :noise-amplitude 0.2)))))
    (add-shape *scene* shape)
    (add-shape *scene* p-sys)
    (add-motion *scene* p-sys)))
;;; hold down space key in 3D view to run animation

(update-scene *scene* 60)               ;do update for batch testing

#|
(Demo 09 particle) climbing particle system ====================================

Climbing particles which follow the surface of a shape, via an intermediate
point-cloud.
|#

#| TODO -- comment out until we have POLYH-CLOSEST-POINT

(format t "  particle-system 09...~%") (finish-output)

(with-clear-scene
  (let* ((shape (make-cube-sphere 6.0 3))
         (cloud (generate-point-cloud shape 40))
         (p-sys (make-particle-system-from-point (p! 0 3 0) 10 (p! -.2 0 -.2) (p! .2 0 .2)
                                                 'climbing-particle
                                                 :support-point-cloud cloud
                                                 :update-angle (range-float (/ pi 8) (/ pi 16))
                                                 :life-span 10)))
    (add-shape *scene* shape)
    (add-shape *scene* p-sys)
    (add-motion *scene* p-sys)))
;;; hold down space key in 3D view to run animation -- gets slow, need to profile code & optimize
;;; suggestion: turn off filled display for a better view (TAB, D, 1)

(update-scene *scene* 20)               ;do update for batch testing
|#

#|
;;; particle-system point-generator-mixin use polyh face centers ---------------

(format t "  particle-system 7...~%") (finish-output)

(with-clear-scene
  (let ((p-gen (make-icosahedron 2.0)))
    (setf (point-source-use-face-centers? p-gen) t)
    (let* ((p-sys (make-particle-system p-gen (p! .2 .2 .2) 1 4 'particle
                                        :life-span 10
                                        :update-angle (range-float (/ pi 16) (/ pi 32))
                                        :spawn-angle (range-float (/ pi 8) (/ pi 16))))
           (sweep-mesh-group (make-sweep-mesh-group (make-circle 0.2 6) p-sys
                                                    :taper 0.0 :twist 0.0)))
      (add-shape *scene* p-gen)
      (add-shape *scene* p-sys)
      (add-shape *scene* sweep-mesh-group)
      (add-motion *scene* p-sys))))
;;; hold down space key in 3D view to run animation

;;; particle-system point-generator-mixin polyhedron ---------------------------

(format t "  particle-system 8...~%") (finish-output)

(with-clear-scene
  (let* ((p-gen (import-obj *example-obj-filename*))
         (p-sys (make-particle-system p-gen (p! .2 .2 .2) 1 4 'dynamic-particle
                                       :force-fields (list (make-instance 'constant-force-field
                                                                          :force-vector (p! 0 -.05 0))))))
    (add-shape *scene* p-gen)
    (add-shape *scene* p-sys)
    (add-motion *scene* p-sys)))
;;; hold down space key in 3D view to run animation -- slow, profile & optimize

;;; particle-system point-generator-mixin particle-system ----------------------

(format t "  particle-system 9...~%") (finish-output)

(with-clear-scene
  (let* ((p-gen (freeze-transform (translate-by (make-superquadric 8 5 2.0 1.0 1.0)
                                                (p! 0 2 0))))
         (p-sys (make-particle-system p-gen (p! .4 .4 .4) 1 1 'particle
                                      :update-angle (range-float (/ pi 16) (/ pi 32)))))
    (add-shape *scene* p-gen)
    (setf (name p-sys) 'p-system-1)
    (add-shape *sce         ne* p-sys)
    (add-motion *scene* p-sys)))
;;; hold down space key in 3D view to run animation

;;; for automated testing
(update-scene *scene* 10)

;;; make new particle-system generate from paths of existing particle-system
(progn
  (clear-motions *scene*)             ;remove exsting particle animator
  (let* ((p-gen (find-shape-by-name *scene* 'p-system-1))
         (p-sys (make-particle-system p-gen (p! .4 .4 .4) 1 1 'particle
                                      :update-angle (range-float (/ pi 16) (/ pi 32)))))
    (setf (name p-sys) 'p-system-2)
    (add-shape *scene* p-sys)
    (add-motion *scene* p-sys)))
;;; hold down space key in 3D view to run animation

;;; for automated testing
(update-scene *scene* 5)

;;; do sweep-extrude  
(let ((group (make-shape-group (sweep-extrude (make-circle 0.25 4)
                                              (find-shape-by-name *scene* 'p-system-2)
                                              :taper 0.0))))
  (set-point-colors-by-uv group (lambda (u v)
                                  (declare (ignore u))
                                  (c-rainbow v)))
    (add-shape *scene* group))

|#

