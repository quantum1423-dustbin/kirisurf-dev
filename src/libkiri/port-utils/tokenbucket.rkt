#lang typed/racket
(require libkiri/common)

(: port-soft-limit (case-> (Input-Port Integer Integer -> Input-Port)
                           (Output-Port Integer Integer  -> Output-Port)))
(define (port-soft-limit prt kbps bucksize)
  (define incrlock (make-semaphore 1))
  (define bucket-limit (* 1024 1024 bucksize))
  (define bucket bucket-limit)
  (define-values (pin pout) (make-pipe 16384))
  ;; Thread that dumps water into the bucket
  (thread
   (thunk
    (let loop()
      (sleep 0.1)
      (with-lock incrlock
        (when (< bucket bucket-limit)
          (set! bucket (+ bucket (quotient (* 1024 kbps) 10)))))
      (loop))))
  ;; Thread that does the copying
  (thread
   (thunk
    (cond
      [(input-port? prt)
       (scopy-port prt pout
                   (lambda (bts)
                     (let wait ()
                       (when (< bucket 0)
                         (sleep 0.1)
                         (wait)))
                     (with-lock incrlock
                       (set! bucket (- bucket (bytes-length bts))))
                     bts))]
      [(output-port? prt)
       (scopy-port pin prt
                   (lambda (bts)
                     (let wait ()
                       (when (< bucket 0)
                         (sleep 0.1)
                         (wait)))
                     (with-lock incrlock
                       (set! bucket (- bucket (bytes-length bts))))
                     bts))])))
  (cond
    [(input-port? prt) pin]
    [(output-port? prt) pout]))


(: port-cascading-limits (Output-Port
                          Integer ; 1mb limit
                          Integer ; 10mb limit
                          Integer ; 100mb limit
                          Integer ; 300mb limit
                          -> Output-Port))
(define (port-cascading-limits out 1mb 10mb 100mb 300mb)
  (define 300mb-layer (port-soft-limit out 300mb 300))
  (define 100mb-layer (port-soft-limit 300mb-layer 100mb 100))
  (define 10mb-layer (port-soft-limit 100mb-layer 10mb 10))
  (define 1mb-layer (port-soft-limit 10mb-layer 1mb 1))
  1mb-layer)

(: port-cascading-limits/in (Input-Port
                          Integer ; 1mb limit
                          Integer ; 10mb limit
                          Integer ; 100mb limit
                          Integer ; 300mb limit
                          -> Input-Port))
(define (port-cascading-limits/in out 1mb 10mb 100mb 300mb)
  (define 300mb-layer (port-soft-limit out 300mb 300))
  (define 100mb-layer (port-soft-limit 300mb-layer 100mb 100))
  (define 10mb-layer (port-soft-limit 100mb-layer 10mb 10))
  (define 1mb-layer (port-soft-limit 10mb-layer 1mb 1))
  1mb-layer)

(provide (all-defined-out))