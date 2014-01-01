#lang racket
(require (planet gh/sha:1:1))

(define (HMAC msg key len)
  (subbytes (hmac-sha512 key msg) 0 len))

(define (HASH msg (len 64))
  (HMAC msg #"kiri1" len))

(define (IVHASH msg)
  (HMAC msg #"hello world" 16))

(define hex bytes->hex-string)

(provide (all-defined-out))