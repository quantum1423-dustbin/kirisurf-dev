#lang racket
(require "common.rkt")

(define (timeout-input time in)
  (define timer time)
  (define das-lock (make-semaphore 4096))
  (define-values (pin pout) (make-pipe 4096))
  (thread
   (thunk
    (scopy-port in pout (λ()
                          (semaphore-wait das-lock)
                          (set! timer time)
                          (semaphore-post das-lock)))))
  (thread
   (thunk
    (let loop()
      (sleep 1/1000)
      (semaphore-wait das-lock)
      (set! timer (sub1 timer))
      (if (zero? timer)
        (begin (semaphore-post das-lock)
               (close-input-port in)
               (close-input-port pin)
               (close-output-port pout))
        (begin (semaphore-post das-lock)
               (loop))))))
  pin)

(define (timeout-output time out)
  (define timer time)
  (define das-lock (make-semaphore 4096))
  (define-values (pin pout) (make-pipe 4096))
  (thread
   (thunk
    (scopy-port pin out (λ()
                          (semaphore-wait das-lock)
                          (set! timer time)
                          (semaphore-post das-lock)))))
  (thread
   (thunk
    (let loop()
      (sleep 1/1000)
      (semaphore-wait das-lock)
      (set! timer (sub1 timer))
      (if (zero? timer)
        (begin (semaphore-post das-lock)
               (close-output-port out)
               (close-input-port pin)
               (close-output-port pout))
        (begin (semaphore-post das-lock)
               (loop))))))
  pout)

(define aaa (tcp-listen 9999 4 #t))
(define-values (cin cout) (tcp-accept aaa))
;(define-values (rin rout) (tcp-connect "google.com" 80))
(define tin (timeout-input 5000 cin))
(define tout (timeout-output 5000 cout))
(scopy-port tin tout)