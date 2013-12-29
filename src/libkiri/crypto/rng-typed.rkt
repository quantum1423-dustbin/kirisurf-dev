#lang typed/racket
(require libkiri/common)
(require/typed libkiri/crypto/rng
               (get-random-bytes (Integer -> Bytes))
               (get-random (Integer -> Integer)))

(provide get-random-bytes
         get-random)