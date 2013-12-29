#lang typed/racket
(require libkiri/common)


(: read-pascal-bytes (Input-Port -> Bytes))
(define (read-pascal-bytes in)
  (define strlen (le->number (eliminate-eof (read-bytes 2 in))))
  (eliminate-eof (read-bytes strlen in)))

(: write-pascal-bytes (Bytes Output-Port -> Void))
(define (write-pascal-bytes bts out)
  (write-bytes (number->le (bytes-length bts) 2) out)
  (write-bytes bts out)
  (void))

(: read-le-number (Integer Input-Port -> Integer))
(define (read-le-number len in)
  (le->number (eliminate-eof (read-bytes len in))))

(: write-le-number (Integer Positive-Integer Output-Port -> Void))
(define (write-le-number num len out)
  (write-bytes (number->le num len) out)
  (void))

;; Structs for the many connection in one thing.

(struct: create-connection
  ((connid : Integer)
   (host : String)
   (port : Integer))
  #:transparent)

(struct: close-connection
  ((connid : Integer))
  #:transparent)

(struct: data
  ((connid : Integer)
   (body : Bytes))
  #:transparent)

(struct: echo ())

(define-type Pack (U create-connection close-connection data echo))

(: read-pack (Input-Port -> Pack))
(define (read-pack in)
  (match (read-byte in)
    [0 (create-connection
        (read-le-number 2 in)
        (bytes->string/utf-8 (read-pascal-bytes in))
        (read-le-number 2 in))]
    [1 (close-connection
        (read-le-number 2 in))]
    [2 (data
        (read-le-number 2 in)
        (read-pascal-bytes in))]
    [3 (echo)]
    [x (error "Protocol mismatch" x)]))

(: write-pack (Pack Output-Port -> Void))
(define (write-pack pk out)
  (match pk
    [(create-connection connid
                        host
                        port) (write-byte 0 out)
                              (write-le-number connid 2 out)
                              (write-pascal-bytes (string->bytes/utf-8 host)
                                                  out)
                              (write-le-number port 2 out)]
    [(close-connection connid) (write-byte 1 out)
                               (write-le-number connid 2 out)]
    [(data connid body) (write-byte 2 out)
                        (write-le-number connid 2 out)
                        (write-pascal-bytes body out)]
    [(echo) (write-byte 3 out)])
  (flush-output out))

(provide (all-defined-out))