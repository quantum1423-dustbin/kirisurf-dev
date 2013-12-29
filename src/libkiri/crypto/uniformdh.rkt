#lang typed/racket
(require libkiri/common)
(require libkiri/crypto/rng-typed)
(require file/sha1)

(struct: key-pair ((private : Integer)
                   (public : Integer)) #:transparent)

;; function that calculates a private key and public key pair
(define (uniformdh-genpair)
  ;We generate 1536-bit number (192-byte number)
  (define private (* 2 (quotient (le->number (get-random-bytes 192)) 2)))
  ;We get the public key
  (define public (expt-mod 2 private GROUP-5))
  (key-pair private (if (< (get-random 100) 50) public (- GROUP-5 public))))

;; function which calculates a shared secret from two keys
(: uniformdh-getsecret (Integer Integer -> Integer))
(define (uniformdh-getsecret local-key
                             remote-key)
  (expt-mod remote-key local-key GROUP-5))

(provide (all-defined-out))