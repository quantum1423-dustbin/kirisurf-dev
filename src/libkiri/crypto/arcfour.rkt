#lang racket
(require libkiri/common)
(require ffi/unsafe
         ffi/unsafe/define)
(require file/sha1)
(require libkiri/crypto/openssl)

(define-crypto RC4_set_key (_fun _pointer _int _pointer -> _void))
(define-crypto RC4
  (_fun _pointer _uint32 _pointer _pointer -> _void))

(define (make-rc4 key)
  (define buffer (malloc 'atomic 16384))
  (define klen (bytes-length key))
  (RC4_set_key buffer klen key)
  (define (toret ip)
    (cond
      [(bytes? ip)
       (define thing (make-bytes (bytes-length ip)))
       (RC4 buffer (bytes-length ip) ip thing)
       thing]
      [else (error "Cannot encrypt non-numeric data: " ip)]))
  (toret (make-bytes 8192))
  toret)

(debug 3 "Arcfour module loaded")


(provide (all-defined-out))