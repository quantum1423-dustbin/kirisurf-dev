#lang typed/racket
(require libkiri/common)
(require libkiri/kiss/structs)
(require libkiri/kiss/hashes-typed)

(: write-packet-to-port (Segment Chugger Output-Port -> Void))
(define (write-packet-to-port pkt hasher out)
  (debug 6 "writing a packet to port")
  (define payload
    (with-output-to-bytes
        (thunk
         (cond
           [(client-greeting? pkt) (write-bytes #"ASAK")
                                   (assert (equal? 'plain-dh 
                                                   (client-greeting-handshake-mode pkt)))
                                   (write-byte 0)
                                   ;; version
                                   (write-byte (client-greeting-version pkt))
                                   ;; public key
                                   (write-bytes (client-greeting-pubkey pkt))
                                   ;; cipher list
                                   (define cdcl (string->bytes/utf-8 
                                                 (string-join (client-greeting-ciphers pkt) ":")))
                                   (write-byte (bytes-length cdcl))
                                   (write-bytes cdcl)]
           [(server-greeting? pkt) (write-bytes #"KASA")
                                   ;; public key
                                   (write-bytes (server-greeting-pubkey pkt))
                                   ;; selected cipher
                                   (define cipher (string->bytes/utf-8
                                                   (server-greeting-cipher pkt)))
                                   (write-byte (bytes-length cipher))
                                   (write-bytes cipher)]
           [(alert? pkt) (write-byte
                          (match (alert-alert-type pkt)
                            ['misc-error 0]
                            ['misc-warning 1]
                            ['echo 2]
                            ['discard 3]
                            ['connection-close 4]
                            ['version-unsupported 5]
                            ['mac-error 6]))
                         (define hmsg (string->bytes/utf-8
                                       (alert-message pkt)))
                         (write-byte (bytes-length hmsg))
                         (write-bytes hmsg)]
           [(data-segment? pkt) (write-bytes (data-segment-body pkt))]
           [else (error "AAAAAAAAAAAAAAAAAA!")]))))
  (debug 6 "payload length is ~a" (bytes-length payload))
  (debug 6 "payload to write determined")
  (define payload-hash (hasher payload))
  (debug 6 "payload hash calculated")
  (define segment-enum
    (cond
      [(or (client-greeting? pkt)
           (server-greeting? pkt)) 0]
      [(alert? pkt) 1]
      [else 2]))
  (debug 6 "segment type calculated")
  (write-byte segment-enum out)
  (debug 6 "wrote segment enum")
  (write-bytes payload-hash out)
  (debug 6 "wrote payload hash ~a of length ~a" 
         payload-hash
         (bytes-length payload-hash))
  (write-bytes (number->le (bytes-length payload) 2) out)
  (debug 6 "wrote payload length ~a" (number->le (bytes-length payload) 2))
  (write-bytes payload out)
  (debug 6 "packet sent!")
  (void))

(: read-packet-from-port (Chugger Input-Port -> Segment))
(define (read-packet-from-port hasher inp)
  (debug 6 "reading packet from port")
  ;; We read the content type enum. This is the first byte.
  (define ctype-enum (eliminate-eof (read-byte inp)))
  (define ctype
    (cond
      ;; handshake
      [(= 0 ctype-enum) 'handshake]
      [(= 1 ctype-enum) 'alert]
      [(= 2 ctype-enum) 'application-data]))
  (debug 6 "content type read")
  ;; We read HMAC
  (define alleged-hmac (read-bytes 32 inp))
  (debug 6 "alleged hmac read")
  ;; Then we read payload
  (define payload-length (le->number (eliminate-eof (read-bytes 2 inp))))
  (debug 6 "payload length is ~a" payload-length)
  (define raw-payload (eliminate-eof (read-bytes payload-length inp)))
  (debug 6 "payload read")
  ;; We then verify the mac
  (assert (equal? (hasher raw-payload)
                  alleged-hmac))
  (debug 6 "hmac verified")
  ;; We then parse the payload
  (define payload
    (cond
      ;; basic data
      [(equal? 'application-data ctype) (data-segment raw-payload)]
      ;; different types of handshakes
      [(equal? 'handshake ctype)
       (match (subbytes raw-payload 0 4)
         ;; ASAK is client greeting
         [#"ASAK" (define handshake-type (match (bytes-ref raw-payload 4)
                                           ;; plain-dh
                                           [0 'plain-dh]
                                           [_ (error "Unsupported handshake type!")]))
                  (define version (bytes-ref raw-payload 5))
                  (define pubkey (subbytes raw-payload 6 518))
                  (define cllen (bytes-ref raw-payload 518))
                  (define clist (bytes->string/utf-8 (subbytes raw-payload
                                                               519
                                                               (+ 519 cllen))))
                  (client-greeting handshake-type
                                   version
                                   pubkey
                                   (string-split clist ":"))]
         ;; KASA is server greeting
         [#"KASA" (define pubkey (subbytes raw-payload 4 516))
                  (define cllen (bytes-ref raw-payload 516))
                  (define cipher (bytes->string/utf-8 (subbytes raw-payload
                                                               517
                                                               (+ 517 cllen))))
                  (server-greeting pubkey
                                   cipher)])]
      ;; alert
      [(equal? 'alert ctype)
       (define alert-type (match (bytes-ref raw-payload 0)
                            [0 'misc-error]
                            [1 'misc-warning]
                            [2 'echo]
                            [3 'discard]
                            [4 'connection-close]
                            [5 'version-unsupported]
                            [6 'ciphers-unsupported]
                            [7 'mac-error]))
       (define message-length (bytes-ref raw-payload 1))
       (define human-message (bytes->string/utf-8 (subbytes raw-payload 2 (+ 2 message-length))))
       (alert alert-type human-message)]
      [else (error "Unknown segment type.")]))
  (debug 6 "payload parsed, reading done")
  payload)

(provide (all-defined-out))

(define test-client-greeting
    (client-greeting
         'plain-dh
         1
         (make-bytes 512)
         (list "arcfour128-drop8192"
           "blowfish512-ofb")))