#lang typed/racket
(require libkiri/common)
(require libkiri/kiss/structs)
(require libkiri/kiss/hashes-typed)
(require libkiri/kiss/helpers)
(require libkiri/crypto/securedh)
(require libkiri/crypto/arcfour-typed)
(require libkiri/crypto/blowfish-typed)


(define ALLOW-BLOWFISH #f)

(: kiss-handshake/server
   (DH-Keys Input-Port Output-Port -> KISS-State))
(define (kiss-handshake/server keys in out)
  (debug 5 "Starting KiSS handshake on server side")
  ;; Wait for the client greeting
  (define their-greeting
    (read-packet-from-port null-hasher in))
  (debug 5 "client greeting read")
  (define our-private (key-pair-private keys))
  (define our-public (key-pair-public keys))
  (match their-greeting
    [(client-greeting 'plain-dh
                      1
                      pubkey
                      ciphers) (debug 5 "~a" ciphers)
                               (cond
                                 [(member "blowfish448-ofb" ciphers)
                                  ;; Return a nice little thingy
                                  (define their-public (le->number pubkey))
                                  (define shared-secret
                                    (number->le (securedh-getsecret our-private
                                                                    their-public) 512))
                                  (define our-greeting
                                    (server-greeting
                                     (number->le our-public 512)
                                     "blowfish448-ofb"))
                                  (write-packet-to-port our-greeting null-hasher out)
                                  (flush-output out)
                                  ;; Form the stuff
                                  (define down-key
                                    (HMAC shared-secret
                                          #"kiss1_down"
                                          56))
                                  (debug 5 "down key is ~a" down-key)
                                  (define up-key
                                    (HMAC shared-secret
                                          #"kiss1_up"
                                          56))
                                  (define down-hasher
                                    (make-hasher (HASH down-key 64)))
                                  (define up-hasher
                                    (make-hasher (HASH up-key 64)))
                                  (define up-crypter (make-blowfish up-key))
                                  (define down-crypter (make-blowfish down-key))
                                  (debug 5 "server handshake done")
                                  (kiss-state
                                   up-hasher
                                   down-hasher
                                   up-crypter
                                   down-crypter)]
                                 [(member "arcfour128-drop8192" ciphers)
                                  ;; Return a nice little thingy
                                  (define their-public (le->number pubkey))
                                  (define shared-secret
                                    (number->le (securedh-getsecret our-private
                                                                    their-public) 512))
                                  (define our-greeting
                                    (server-greeting
                                     (number->le our-public 512)
                                     "arcfour128-drop8192"))
                                  (write-packet-to-port our-greeting null-hasher out)
                                  (flush-output out)
                                  ;; Form the stuff
                                  (define down-key
                                    (HMAC shared-secret
                                          #"kiss1_down"
                                          16))
                                  (debug 5 "down key is ~a" down-key)
                                  (define up-key
                                    (HMAC shared-secret
                                          #"kiss1_up"
                                          16))
                                  (define down-hasher
                                    (make-hasher (HASH down-key 64)))
                                  (define up-hasher
                                    (make-hasher (HASH up-key 64)))
                                  (define up-crypter (make-rc4 up-key))
                                  (define down-crypter (make-rc4 down-key))
                                  (debug 5 "server handshake done")
                                  (kiss-state
                                   up-hasher
                                   down-hasher
                                   up-crypter
                                   down-crypter)]
                                 [else (define our-alert
                                         (alert 'ciphers-unsupported
                                                "ダメだよ"))
                                       (write-packet-to-port our-alert null-hasher out)
                                       (flush-output out)
                                       (error "Ciphers unsupported.")])]
    [_ (error "Protocol mismatch!")]))

(: kiss-handshake/client
   (Input-Port Output-Port (Bytes -> Boolean) -> KISS-State))
(define (kiss-handshake/client in out validator)
  (debug 5 "Starting KiSS handshake on client side")
  ;; We generate our diffie hellman pair
  (define our-keys (securedh-genpair))
  (define our-private
    (key-pair-private our-keys))
  (define our-public
    (key-pair-public our-keys))
  (debug 5 "client keypair generated")
  
  ;; Construct client greeting
  (define our-greeting
    (client-greeting
     'plain-dh
     1
     (number->le our-public 512)
     (list "arcfour128-drop8192"
           (if ALLOW-BLOWFISH "blowfish448-ofb" "dummy"))))
  
  ;; Send greeting
  (write-packet-to-port our-greeting
                        null-hasher
                        out)
  (flush-output out)
  (debug 5 "client greeting sent")
  ;; Wait for their greeting
  (define their-greeting
    (read-packet-from-port null-hasher in))
  (debug 5 "server greeting read")
  (match their-greeting
    [(server-greeting pubkey selcipher) (define their-public (le->number pubkey))
                                        (assert (validator pubkey))
                                        (define shared-secret
                                          (number->le (securedh-getsecret our-private
                                                                          their-public) 512))
                                        (match selcipher
                                          ["arcfour128-drop8192"
                                           (define down-key (HMAC shared-secret
                                                                  #"kiss1_down"
                                                                  16))
                                           (debug 5 "down key is ~a" down-key)
                                           (define up-key (HMAC shared-secret
                                                                #"kiss1_up"
                                                                16))
                                           ;; Now make the hashers
                                           (define down-hasher
                                             (make-hasher (HASH down-key 64)))
                                           (define up-hasher
                                             (make-hasher (HASH up-key 64)))
                                           (define up-crypter (make-rc4 up-key))
                                           (define down-crypter (make-rc4 down-key))
                                           (debug 5 "handshake done; rc4 negotiated")
                                           (kiss-state
                                            up-hasher
                                            down-hasher
                                            up-crypter
                                            down-crypter)]
                                          ["blowfish448-ofb"
                                           (define down-key
                                             (HMAC shared-secret
                                                   #"kiss1_down"
                                                   56))
                                           (define up-key
                                             (HMAC shared-secret
                                                   #"kiss1_up"
                                                   56))
                                           ;; now make the hashers
                                           (define down-hasher
                                             (make-hasher (HASH down-key 64)))
                                           (define up-hasher
                                             (make-hasher (HASH up-key 64)))
                                           (define up-crypter (make-blowfish up-key))
                                           (define down-crypter (make-blowfish down-key))
                                           (debug 5 "handshake done; blowfish negotiated")
                                           (kiss-state
                                            up-hasher
                                            down-hasher
                                            up-crypter
                                            down-crypter)])]
    [(alert 'versions-unsupported msg) (error "KiSS version not supported." msg)]
    [(alert 'ciphers-unsupported msg) (error "Cannot agree on ciphers." msg)]
    [_ (error "Protocol mismatch.")]))


(provide (all-defined-out))