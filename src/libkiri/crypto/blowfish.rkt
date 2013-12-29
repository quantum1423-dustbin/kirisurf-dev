#lang racket
(require libkiri/common)
(require libkiri/untyped)
(require libkiri/crypto/openssl)
(require libkiri/crypto/rng)
(require file/sha1)
(require ffi/unsafe
         ffi/unsafe/define)

;  void BF_set_key(BF_KEY *key, int len, const unsigned char *data);
(define-crypto BF_set_key
  (_fun _pointer _int _pointer -> _void))

;  void BF_ofb64_encrypt(const unsigned char *in, unsigned char *out,
;          long length, BF_KEY *schedule, unsigned char *ivec, int *num);
(define-crypto BF_ofb64_encrypt
  (_fun _pointer _pointer _long _pointer _pointer _pointer -> _void))

(define (make-blowfish key)
  (define schedule (malloc 'atomic 16384))
  (define ctr (make-bytes 8))
  (define iv (make-bytes 8))
  (BF_set_key schedule (bytes-length key) key)
  (define (ret to-enc)
    (cond
      [(bytes? to-enc) (define toret (make-bytes (bytes-length to-enc)))
                       (BF_ofb64_encrypt to-enc 
                                         toret (bytes-length to-enc) schedule 
                                         iv ctr)
                       toret]
      [(number? to-enc) (bytes-ref (ret (bytes to-enc)) 0)]
      [else (error "Non-numeric data fed to blowfish!" to-enc)]))
  ret)

;; Tests
(let ()
  (define chugger (make-blowfish #"omgomgomg"))
  (assert/ut (equal? #"XW\311\245\321" (chugger #"abcde")))
  (assert/ut (equal? "b65ce0e910bf64fb84be92a3122afa46131cf0ac"
                  (sha1 (open-input-bytes (chugger (make-bytes 65536))))))
  (debug 3 "Blowfish module loaded")
  (void))

(provide (all-defined-out))