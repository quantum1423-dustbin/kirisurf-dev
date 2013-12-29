#lang typed/racket
(require libkiri/kiss/obfuscation)
(require libkiri/kiss/hashes-typed)
(require libkiri/crypto/securedh)
(require libkiri/kiss/transport)
(require libkiri/common)

;; Kirisurf is basically obfs in ssl in obfs.

;; Authenticates the ports as a client
(: authenticate-ports-with-check ((Bytes -> Boolean) Input-Port Output-Port
                                        -> (values Input-Port Output-Port)))
(define (authenticate-ports-with-check auther in out)
  ;; KiSS layer
  (define-values (sob-in sob-out)
    (ports->kiss-ports/client in out
                              auther))
  (values sob-in sob-out))

;; Authenticated accept as server
(: authenticated-accept (Input-Port Output-Port
                                    -> (values Input-Port Output-Port)))
(define (authenticated-accept in out)
  ;; Set up ctx for ssl
  (define my-key 
    (match (with-input-from-file (etc-path "identity.kiridh") read)
      [`(key-pair ,(? exact-integer? private) 
                  ,(? exact-integer? public)) (key-pair private public)]
      [_ (error "Can't read the DH keys!")]))
  ;; KiSS layer
  (define-values (sob-in sob-out)
    (ports->kiss-ports/server my-key in out))
  (values sob-in sob-out))

(provide (all-defined-out))