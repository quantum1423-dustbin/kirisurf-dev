#lang racket
(require openssl)

(define-syntax with-lock/ut
  (syntax-rules ()
    [(_ lck exp1 ...) (with-cleanup/ut (thunk (semaphore-post lck))
                        (semaphore-wait lck)
                        exp1 ...)]))

(define-syntax assert/ut
  (syntax-rules ()
    [(_ exp)
     (if exp (void)
         (error "Assertion failed!" (quote exp)))]))

(define-syntax-rule (with-cleanup/ut thnk exp1 ...)
  (dynamic-wind
   void
   (thunk exp1 ...)
   thnk))

(define (ssl-ip prt)
  (define-values (a b) (ssl-addresses prt))
  b)

(define (_with-timeout milli thnk)
  (define return-value #f)
  (define thrd (thread (thunk (set! return-value (thnk)))))
  (define tevt (thread-dead-evt thrd))
  (when (not (sync/timeout (exact->inexact (/ milli 1000)) tevt))
    (kill-thread thrd)
    (error "timeout"))
  return-value)

(define _make_input_port make-input-port)
(define _make_output_port make-output-port)

(provide (all-defined-out))