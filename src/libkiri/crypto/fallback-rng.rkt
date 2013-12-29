#lang racket
(require file/sha1)
(require libkiri/common)
(require libkiri/crypto/arcfour)
;; This file defines a fallback random number generator for platforms without /dev/urandom.
;; This is NOT very secure! A warning will be issued when this RNG must be used.

(define (gather-entropy)
  (define hdir (sha1-bytes
                (open-input-string ($ "dir" (path->string (find-system-path 'home-dir))))))
  (define tdir (sha1-bytes
                (open-input-string ($ "dir" (path->string (find-system-path 'temp-dir))))))
  (define timehash (sha1-bytes
                    (open-input-bytes
                     (number->le (inexact->exact
                                  (floor (* 1000 (current-inexact-milliseconds))))
                                 20))))
  (define toret (make-bytes 20))
  (for ([i 20])
    (bytes-set! toret i
                (bitwise-xor (bytes-ref hdir i)
                             (bytes-ref tdir i)
                             (bytes-ref timehash i))))
  
  toret)

(define chugger #f)

(define (rng-initialize)
  (debug 1 "WARNING: Insecure RNG seeded.")
  (set! chugger (make-rc4 (gather-entropy))))

(define (get-fallback-bytes num)
  (if chugger
      (chugger (make-bytes num))
      (error "RNG not initialized!")))

(provide get-fallback-bytes rng-initialize)