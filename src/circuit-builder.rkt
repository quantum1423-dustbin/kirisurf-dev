#lang typed/racket
(require libkiri/protocol/subcircuit/client)
(require libkiri/protocol/directory/frontend)

(: build-circuit ((Listof Symbol)
                  -> (values Input-Port
                             Output-Port)))
(define (build-circuit nlst)
  (define-values (ihost iport)
    (node-host (car nlst)))
  (define automaton
    (make-circuit (car nlst)
                  ihost
                  iport))
  (for ([nd (cdr nlst)])
    (automaton 'extend nd))
  (apply values (automaton 'seal)))

(provide (all-defined-out))