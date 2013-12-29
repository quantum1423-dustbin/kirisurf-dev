#lang racket
(require libkiri/common)
(require libkiri/protocol/subcircuit/support)
(require libkiri/crypto/rng)
(require libkiri/kiss/obfuscation)
(require libkiri/protocol/directory/frontend)
(require libkiri/protocol/authentication)

;; This function returns a "circuit automaton": a special function.
;; 'extend nick -> circuit extends to the said nick
;; 'seal -> exits at current node


;(: make-circuit (Symbol String Integer -> (U ('extend Symbol -> Void)
;                                             ('current-circuit -> (Listof Symbol))
;                                             ('seal -> (List Input-Port Output-Port)))))
(define (make-circuit nick host port)
  (define-values (raw-in raw-out) (obfs-connect host port))
  (define-values (rin rout) (authenticate-ports-with-check
                             (node-authenticator nick) raw-in raw-out))
  ;(: circuit (Listof Symbol))
  (define circuit (list nick))
  (lambda x
    (match x
      [`(extend ,(? symbol? nck))
       (debug 5 "extending circuit to ~a" nck)
       (write-byte 1 rout)
       (write-byte (string-length (symbol->string nck)))
       (write-bytes (string->bytes/utf-8 (symbol->string nck)))
       (flush-output rout)
       (define-values (nin nout)
         (authenticate-ports-with-check
          (node-authenticator nck) rin rout))
       (set! rin nin)
       (set! rout nout)
       (set! circuit (cons nck circuit))]
      ['(seal) (write-byte 2 rout)
               (list rin rout)]
      [_ (error 'omg)])))

(provide make-circuit)