#lang typed/racket
(require libkiri/common)
(require libkiri/crypto/rng-typed)
(require file/sha1)

(struct: key-pair ((private : Integer)
                   (public : Integer)) #:transparent)

(define-type DH-Keys key-pair)

;; function that calculates a private key and public key pair
(define (securedh-genpair)
  ;We generate 4096-bit number (512-byte number)
  (define private (le->number (get-random-bytes 512)))
  ;We get the public key
  (define public (expt-mod 2 private GROUP-16))
  (key-pair private public))

;; function which calculates a shared secret from two keys
(: securedh-getsecret (Integer Integer -> Integer))
(define (securedh-getsecret local-key
                             remote-key)
  (expt-mod remote-key local-key GROUP-16))

(provide (all-defined-out))