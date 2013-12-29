#lang typed/racket
(require/typed "hashes.rkt"
               (HMAC (Bytes Bytes Integer -> Bytes))
               (IVHASH (Bytes -> Bytes))
               (HASH (Bytes Integer -> Bytes)))
(require libkiri/common)

(: make-hasher (Bytes -> (Bytes -> Bytes)))
(define (make-hasher key)
  (define packnum 0)
  (lambda (bts)
    (define toret (HMAC (bytes-append bts (number->le packnum 64)) key 32))
    (set! packnum (add1 packnum))
    toret))

(define ____ #"hashhashhashhashhashhashhashhash")

(: null-hasher (Bytes -> Bytes))
(define (null-hasher bts)
  ____)

(: make-bad-hasher (Bytes -> (Bytes -> Bytes)))
(define (make-bad-hasher blah)
  null-hasher)

;(set! make-hasher make-bad-hasher)

(provide HMAC HASH make-hasher null-hasher IVHASH)