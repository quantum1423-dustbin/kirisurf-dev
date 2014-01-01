#lang typed/racket
(require libkiri/common)
(require libkiri/protocol/subcircuit/client)
(require libkiri/protocol/directory/frontend)

(: build-circuit ((Listof Symbol)
                  -> (values Input-Port
                             Output-Port)))
(define (build-circuit nlst)
  (with-handlers ([exn:fail?
                   (λ(x) (error "Circuit failed to build."))])
    (define-values (ihost iport)
      (node-host (car nlst)))
    (define automaton
      (make-circuit (car nlst)
                    ihost
                    iport))
    (for ([nd (cdr nlst)])
      (with-timeout 30000 
        (thunk (automaton 'extend nd))))
    (apply values (automaton 'seal))))

(provide (all-defined-out))