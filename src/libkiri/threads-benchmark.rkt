#lang racket
(require libkiri/common)
(require libkiri/crypto/blowfish)
(require libkiri/crypto/arcfour)
(require libkiri/crypto/rng)

(define listener (tcp-listen 55555 4 #t))

(let loop()
  (define-values (cin cout) (tcp-accept listener))
  (thread
   (thunk
    (scopy-port cin cout)))
  (loop))