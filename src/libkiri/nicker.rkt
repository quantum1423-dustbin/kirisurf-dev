#lang typed/racket
(require libkiri/common)
(require libkiri/crypto/rng-typed)
(require libkiri/kiss/hashes-typed)


;; iroha
(define iroha-chars
  (string->list
   "abcdefghijklmnopqrstuvwxyz234567"))

(: num->char (Integer -> Char))
(define (num->char num)
  (list-ref iroha-chars num))

(: num->b32lst (Integer -> (Listof Integer)))
(define (num->b32lst num)
  (cond
    [(zero? num) empty]
    [else (cons (modulo num 32)
                (num->b32lst (quotient num 32)))]))

(: num->b32 (Integer -> String))
(define (num->b32 int)
  (list->string (map num->char (num->b32lst int))))

(: b32hash (Bytes -> Symbol))
(define (b32hash bts)
  (string->symbol
   (num->b32 (le->number (IVHASH bts)))))

(provide (all-defined-out))

