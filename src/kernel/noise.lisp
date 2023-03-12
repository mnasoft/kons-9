(in-package :kons-9)

;;;; perlin noise ==============================================================

(defconstant noise-numpts 512)
(defconstant noise-p1 173.0)
(defconstant noise-p2 263.0)
(defconstant noise-p3 337.0)
(defconstant noise-phi 0.6180339)

(defvar *noise-pts* (make-array noise-numpts :element-type 'float :initial-element 0.0))

(defun init-noise ()
  (dotimes (i noise-numpts)
    (setf (aref *noise-pts* i) (random 1.0))))

(init-noise)

(defun noise (p)
  (let* ((x (p:x p))
         (y (p:y p))
         (z (p:z p))

         (xi (floor x))
         (yi (floor y))
         (zi (floor z))

         (xa (floor (* noise-p1 (mod (*    xi    noise-phi) 1))))
         (xb (floor (* noise-p1 (mod (* (+ xi 1) noise-phi) 1))))
         (xc (floor (* noise-p1 (mod (* (+ xi 2) noise-phi) 1))))
         (ya (floor (* noise-p2 (mod (*    yi    noise-phi) 1))))
         (yb (floor (* noise-p2 (mod (* (+ yi 1) noise-phi) 1))))
         (yc (floor (* noise-p2 (mod (* (+ yi 2) noise-phi) 1))))
         (za (floor (* noise-p3 (mod (*    zi    noise-phi) 1))))
         (zb (floor (* noise-p3 (mod (* (+ zi 1) noise-phi) 1))))
         (zc (floor (* noise-p3 (mod (* (+ zi 2) noise-phi) 1))))

         (p000 (aref *noise-pts* (mod (+ xa ya za) noise-numpts)))
         (p100 (aref *noise-pts* (mod (+ xb ya za) noise-numpts)))
         (p200 (aref *noise-pts* (mod (+ xc ya za) noise-numpts)))
         (p010 (aref *noise-pts* (mod (+ xa yb za) noise-numpts)))
         (p110 (aref *noise-pts* (mod (+ xb yb za) noise-numpts)))
         (p210 (aref *noise-pts* (mod (+ xc yb za) noise-numpts)))
         (p020 (aref *noise-pts* (mod (+ xa yc za) noise-numpts)))
         (p120 (aref *noise-pts* (mod (+ xb yc za) noise-numpts)))
         (p220 (aref *noise-pts* (mod (+ xc yc za) noise-numpts)))
         (p001 (aref *noise-pts* (mod (+ xa ya zb) noise-numpts)))
         (p101 (aref *noise-pts* (mod (+ xb ya zb) noise-numpts)))
         (p201 (aref *noise-pts* (mod (+ xc ya zb) noise-numpts)))
         (p011 (aref *noise-pts* (mod (+ xa yb zb) noise-numpts)))
         (p111 (aref *noise-pts* (mod (+ xb yb zb) noise-numpts)))
         (p211 (aref *noise-pts* (mod (+ xc yb zb) noise-numpts)))
         (p021 (aref *noise-pts* (mod (+ xa yc zb) noise-numpts)))
         (p121 (aref *noise-pts* (mod (+ xb yc zb) noise-numpts)))
         (p221 (aref *noise-pts* (mod (+ xc yc zb) noise-numpts)))
         (p002 (aref *noise-pts* (mod (+ xa ya zc) noise-numpts)))
         (p102 (aref *noise-pts* (mod (+ xb ya zc) noise-numpts)))
         (p202 (aref *noise-pts* (mod (+ xc ya zc) noise-numpts)))
         (p012 (aref *noise-pts* (mod (+ xa yb zc) noise-numpts)))
         (p112 (aref *noise-pts* (mod (+ xb yb zc) noise-numpts)))
         (p212 (aref *noise-pts* (mod (+ xc yb zc) noise-numpts)))
         (p022 (aref *noise-pts* (mod (+ xa yc zc) noise-numpts)))
         (p122 (aref *noise-pts* (mod (+ xb yc zc) noise-numpts)))
         (p222 (aref *noise-pts* (mod (+ xc yc zc) noise-numpts)))

         (xf (- x xi))
         (xt (* xf xf))
         (x2 (* .5 xt))
         (x1 (- (+ .5 xf) xt))
         (x0 (- (+ .5 x2) xf))

         (yf (- y yi))
         (yt (* yf yf))
         (y2 (* .5 yt))
         (y1 (- (+ .5 yf) yt))
         (y0 (- (+ .5 y2) yf))

         (zf (- z zi))
         (zt (* zf zf))
         (z2 (* .5 zt))
         (z1 (- (+ .5 zf) zt))
         (z0 (- (+ .5 z2) zf)))

    (+ (* z0 (+ (* y0 (+ (* x0 p000) (* x1 p100) (* x2 p200)))
                (* y1 (+ (* x0 p010) (* x1 p110) (* x2 p210)))
                (* y2 (+ (* x0 p020) (* x1 p120) (* x2 p220)))))
       (* z1 (+ (* y0 (+ (* x0 p001) (* x1 p101) (* x2 p201)))
                (* y1 (+ (* x0 p011) (* x1 p111) (* x2 p211)))
                (* y2 (+ (* x0 p021) (* x1 p121) (* x2 p221)))))
       (* z2 (+ (* y0 (+ (* x0 p002) (* x1 p102) (* x2 p202)))
                (* y1 (+ (* x0 p012) (* x1 p112) (* x2 p212)))
                (* y2 (+ (* x0 p022) (* x1 p122) (* x2 p222))))))))

(defun turbulence (p n-octaves)
  (let ((sum 0.0)
        (scale 1.0))
    (dotimes (i n-octaves)
      (incf sum (/ (noise (p:scale p scale)) (* scale 2)))
      (setf scale (* scale 2)))
    sum))

(defun noise-gradient (p &optional (delta 0.01))
  (let* ((x (p:x p))
         (y (p:y p))
         (z (p:z p))
         (dx (- (noise (p! (+ x delta) y z)) (noise (p! (- x delta) y z))))
         (dy (- (noise (p! x (+ y delta) z)) (noise (p! x (- y delta) z))))
         (dz (- (noise (p! x y (+ z delta))) (noise (p! x y (- z delta))))))
    (p! dx dy dz)))

(defun color-noise (p &optional (delta 0.01))
  (let ((pn (p:normalize (noise-gradient p delta))))
    (c! (abs (p:x pn)) (abs (p:y pn)) (abs (p:z pn)))))

