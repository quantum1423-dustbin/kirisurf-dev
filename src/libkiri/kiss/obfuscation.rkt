#lang typed/racket
(require libkiri/crypto/arcfour-typed)
(require libkiri/crypto/blowfish-typed)
(require libkiri/crypto/rng-typed)
(require libkiri/crypto/uniformdh)
(require libkiri/common)
(require libkiri/untyped)
(require/typed "hashes.rkt"
               (HMAC (Bytes Bytes Integer -> Bytes)))

(define PIPE-SIZE 16384)
(define make-cipher make-rc4)

(: OBFS-TABLE (HashTable Input-Port (List String Integer)))
(define OBFS-TABLE (make-weak-hash))

;; Replacement for tcp-connect
(: obfs-connect (String Integer -> (values Input-Port Output-Port)))
(define (obfs-connect host port)
  (define-values (raw-in raw-out) (tcp-connect host port))
  (ports->obfs/client raw-in raw-out))

;; Replacement for tcp-accept
(: obfs-accept (TCP-Listener -> (values Input-Port Output-Port)))
(define (obfs-accept lstnr)
  (define-values (raw-in raw-out) (tcp-accept lstnr))
  (define-values (lhost lport rhost rport) (tcp-addresses raw-in #t))
  (define-values (in out) (ports->obfs/server raw-in raw-out))
  (hash-set! OBFS-TABLE in (list rhost rport))
  (values in out))

(: obfs-address (Input-Port -> (values String Integer)))
(define (obfs-address in)
  (apply values (hash-ref OBFS-TABLE in)))

;; Replacement for server-with-dispatch
;; Generic TCP server thingy
(: obfs-server-with-dispatch (Integer (Input-Port Output-Port -> Void)
                                      -> TCP-Listener))
(define (obfs-server-with-dispatch port lmbd)
  (define toret (tcp-listen port 4 #t))
  (thread
   (thunk
    (let loop()
      (define-values (in out) (obfs-accept toret))
      (thread
       (thunk
        (with-cleanup (λ() (close-input-port in)
                        (close-output-port out))
                      (lmbd in out))))
      (loop))))
  toret)


;; Port to obfs port, client
(: ports->obfs/client 
   (Input-Port Output-Port
               -> (values Input-Port Output-Port)))
(define (ports->obfs/client in out)
  (define-values (upstate downstate) (run-obfs-handshake/client in out))
  (values
   (chugger-input-port downstate in)
   (chugger-output-port upstate out)))

;; Port to obfs port, server
(: ports->obfs/server 
   (Input-Port Output-Port
               -> (values Input-Port Output-Port)))
(define (ports->obfs/server in out)
  (define-values (upstate downstate) (run-obfs-handshake/server in out))
  (values
   (chugger-input-port upstate in)
   (chugger-output-port downstate out)))

;; Run the obfuscation as a client
(: run-obfs-handshake/client
   (Input-Port Output-Port
               -> (values Chugger Chugger)))
(define (run-obfs-handshake/client in out)
  (debug 4 "Running client obfs handshake...")
  (define my-key (uniformdh-genpair))
  (define our-private (key-pair-private my-key))
  (define our-public (key-pair-public my-key))
  (debug 5 "Local obfs keypair derived")
  (write-bytes (number->le our-public 192) out)
  (flush-output out)
  (debug 5 "Local obfs public key sent")
  (define their-public (le->number (eliminate-eof (read-bytes 192 in))))
  (debug 5 "Remote obfs key received")
  (define da-secret (uniformdh-getsecret our-private their-public))
  (debug 5 "Shared secret derived")
  (define upkey (HMAC (number->le da-secret 192)
                      #"kissobfs-upstream"
                      16))
  (define downkey (HMAC (number->le da-secret 192)
                        #"kissobfs-downstream"
                        16))
  (define upstate (make-cipher upkey))
  (define downstate (make-cipher downkey))
  (define padding-length (get-random 65535))
  (write-bytes (number->le padding-length 2) out)
  (write-bytes (upstate (make-bytes padding-length)) out)
  (flush-output out)
  (debug 5 "Random padding sent")
  (define their-plength (le->number (eliminate-eof (read-bytes 2 in))))
  (define their-pad (downstate (eliminate-eof (read-bytes their-plength in))))
  (assert/ut (andmap zero? (bytes->list their-pad)))
  (debug 5 "Random padding read")
  (debug 4 "Client obfs handshake done!")
  (values
   upstate
   downstate))

(: run-obfs-handshake/server
   (Input-Port Output-Port
               -> (values Chugger Chugger)))
(define (run-obfs-handshake/server in out)
  (debug 4 "Running server obfs handshake...")
  (define their-public (le->number (eliminate-eof (read-bytes 192 in))))
  (debug 5 "Remote obfs public key received")
  (define my-key (uniformdh-genpair))
  (define our-private (key-pair-private my-key))
  (define our-public (key-pair-public my-key))
  (debug 5 "Local obfs keypair derived")
  (write-bytes (number->le our-public 192) out)
  (flush-output out)
  (debug 5 "Local obfs keypair sent")
  (define da-secret (uniformdh-getsecret our-private their-public))
  (debug 5 "Shared secret derived")
  (define upkey (HMAC (number->le da-secret 192)
                      #"kissobfs-upstream"
                      16))
  (define downkey (HMAC (number->le da-secret 192)
                        #"kissobfs-downstream" 
                        16))
  (define upstate (make-cipher upkey))
  (define downstate (make-cipher downkey))
  (define padding-length (get-random 65535))
  (write-bytes (number->le padding-length 2) out)
  (write-bytes (downstate (make-bytes padding-length)) out)
  (flush-output out)
  (debug 5 "Random padding sent")
  (define their-plength (le->number (eliminate-eof (read-bytes 2 in))))
  (define their-pad (upstate (eliminate-eof (read-bytes their-plength in))))
  (assert/ut (andmap zero? (bytes->list their-pad)))
  (debug 5 "Random padding read")
  (debug 4 "Server obfs handshake done!")
  (values
   upstate
   downstate))

(provide (all-defined-out))