#lang typed/racket
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
      (automaton 'extend nd))
    (apply values (automaton 'seal))))

(provide (all-defined-out))

(build-circuit
   '(kbr7va3sf4v5sg4ezcdqoskx3gmqebw4uskatyyrl2lksutryprb
  t2nhasmbdlyjqxuj2hap35a2sjp4l2ix4c2nhod2l6yj3mrsx5t
  hn72zoodp7bsgantwrlrtmzpna3u7bpr3gt4nprsa33v7znu6kg))