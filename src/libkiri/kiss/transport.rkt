#lang typed/racket
(require libkiri/common)
(require libkiri/kiss/structs)
(require libkiri/kiss/hashes-typed)
(require libkiri/kiss/helpers)
(require libkiri/kiss/handshake)
(require libkiri/kiss/obfuscation)
(require libkiri/crypto/securedh)
(require libkiri/crypto/arcfour-typed)
(require libkiri/crypto/blowfish-typed)


(: ports->kiss-ports/server (DH-Keys Input-Port Output-Port
                                     -> (values Input-Port Output-Port)))
(define (ports->kiss-ports/server keypair in out)
  (define master-state
    (kiss-handshake/server keypair in out))
  (define-values
    (up-hasher down-hasher up-crypter down-crypter)
    (match master-state
      [(kiss-state a b c d) (values a b c d)]))
  (define-values (upin upout) (make-pipe 65536))
  (define-values (downin downout) (make-pipe 65536))
  ;; Downstream
  (define downstream-thread
    (thread
     (thunk
      (with-cleanup (λ() (close-input-port in) (close-output-port out))
        (let: loop : Void ()
          (define new-packet (read-bytes-avail downin))
          (cond
            [(eof-object? new-packet) (write-packet-to-port
                                       (alert 'connection-close "adiós")
                                       down-hasher
                                       out)
                                      (flush-output out)]
            [else (write-packet-to-port
                   (data-segment (down-crypter new-packet))
                   down-hasher
                   out)
                  (flush-output out)
                  (loop)]))))))
  (define upstream-thread
    (thread
     (thunk
      (with-cleanup (λ() (close-input-port in) (close-output-port out))
        (let: loop : Void()
          (define new-segment (read-packet-from-port
                               up-hasher
                               in))
          (match new-segment
            [(alert 'connection-close msg) (void)]
            [(alert other msg) (error other msg)
                               (void)]
            [(data-segment thing) (write-bytes (up-crypter thing) upout)
                                  (flush-output upout)
                                  (loop)]))))))
  (values upin downout))

(: ports->kiss-ports/client (Input-Port Output-Port (Bytes -> Boolean)
                                        -> (values Input-Port Output-Port)))
(define (ports->kiss-ports/client in out validator)
  (define master-state
    (kiss-handshake/client in out validator))
  (define-values
    (up-hasher down-hasher up-crypter down-crypter)
    (match master-state
      [(kiss-state a b c d) (values a b c d)]))
  (define-values (upin upout) (make-pipe 65536))
  (define-values (downin downout) (make-pipe 65536))
  ;; Upstream
  (define upstream-thread
    (thread
     (thunk
      (with-cleanup (λ() (close-input-port in) (close-output-port out))
        (let: loop : Void ()
          (define new-data (read-bytes-avail upin))
          (cond
            [(eof-object? new-data) (write-packet-to-port
                                     (alert 'connection-close "さようなら")
                                     up-hasher
                                     out)
                                    (flush-output out)]
            [else (write-packet-to-port
                   (data-segment (up-crypter new-data))
                   up-hasher
                   out)
                  (flush-output out)
                  (loop)]))))))
  (define downstream-thread
    (thread
     (thunk
      (with-cleanup (λ() (close-input-port in) (close-output-port out))
        ;; Downstream
        (let: loop : Void ()
          (define new-data (read-packet-from-port
                            down-hasher
                            in))
          (match new-data
            [(alert 'connection-close msg) (void)]
            [(alert other msg) (error other msg)
                               (void)]
            [(data-segment bts) (write-bytes (down-crypter bts) downout)
                                (flush-output downout)
                                (loop)]))))))
  (values downin upout))

(provide (all-defined-out))



(define (__test_kiss)
  ;; Testing
  (define blah
    (obfs-server-with-dispatch
     55555
     (lambda (in out)
       (define-values (cin cout) (ports->kiss-ports/server (securedh-genpair) in out))
       (copy-port cin cout))))
  (define-values (rin rout) (obfs-connect "localhost" 55555))
  (define-values (gin gout)
    (ports->kiss-ports/client rin rout (λ(x) #t)))
  (thread (thunk (copy-port (current-input-port) gout)))
  (copy-port gin (current-output-port))
  (void))

;(__test_kiss)