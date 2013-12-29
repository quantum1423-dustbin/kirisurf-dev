#lang typed/racket
(require/typed libkiri/crypto/arcfour
               (make-rc4
                (Bytes -> (Bytes -> Bytes))))

(provide make-rc4)