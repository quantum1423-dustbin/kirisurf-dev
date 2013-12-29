#lang typed/racket
(require/typed libkiri/crypto/blowfish
               (make-blowfish
                (Bytes -> (Bytes -> Bytes))))

(provide make-blowfish)