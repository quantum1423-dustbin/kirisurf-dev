#lang racket
(require libkiri/common)
(require libkiri/crypto/fallback-rng)

(when (equal? 'windows (system-type))
  (rng-initialize))

;; function that provides random bytestring of given length
(define (get-random-bytes num)
  (cond
    [(equal? 'windows (system-type))
     (get-fallback-bytes num)]
    [else
     (with-input-from-file
         "/dev/urandom"
       (thunk
        (read-bytes num)))]))

;; function that provides a random number
(define (get-random (limit 0) (bytes 1024))
  (cond
    [(zero? limit) (le->number (get-random-bytes bytes))]
    [else
     (define candidate (le->number (get-random-bytes bytes)))
     (cond
       [(< candidate limit) candidate]
       [(> limit (expt 256 (sub1 bytes))) (get-random limit bytes)]
       [else (get-random limit (quotient bytes 2))])]))

(provide (all-defined-out))