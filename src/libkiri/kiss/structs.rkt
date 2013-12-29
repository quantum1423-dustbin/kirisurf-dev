#lang typed/racket

(define-type Segment (U client-greeting server-greeting alert data-segment))
(define-type Content-Type (U 'handshake 'alert 'application-data))
(define-type Handshake-Mode (U 'plain-dh))
(define-type Alert-Type (U 'misc-error
                           'misc-warning
                           'echo
                           'discard
                           'connection-close
                           'version-unsupported
                           'ciphers-unsupported
                           'mac-error))

(struct: client-greeting
  ((handshake-mode : Handshake-Mode)
   (version : Integer)
   (pubkey : Bytes)
   (ciphers : (Listof String)))
  #:transparent)

(struct: server-greeting
  ((pubkey : Bytes)
   (cipher : String))
  #:transparent)

(struct: alert
  ((alert-type : Alert-Type)
   (message : String))
  #:transparent)

(struct: data-segment
  ((body : Bytes))
  #:transparent)

(struct: kiss-state
  ((uphasher : (Bytes -> Bytes))
   (downhasher : (Bytes -> Bytes))
   (upcrypter : (Bytes -> Bytes))
   (downcrypter : (Bytes -> Bytes)))
  #:transparent)

(define-type KISS-State kiss-state)

(provide (all-defined-out))