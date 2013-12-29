#lang racket
(require ffi/unsafe
         ffi/unsafe/define)
(define-ffi-definer define-crypto 
  (ffi-lib (match (system-type)
             ['unix "libcrypto"]
             ['macosx "libcrypto"]
             ['windows "libeay32"]) '("1" "0" "1.0.0" "10"
                                          "9" "8" "7" "6" "5"
                                          "4" "3" "2" #f)))

(provide (all-defined-out))