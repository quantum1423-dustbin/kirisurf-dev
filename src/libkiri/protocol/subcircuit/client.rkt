#lang typed/racket
(require/typed "client-untyped.rkt"
               (make-circuit (Symbol String Integer -> 
                                     (case-> ('extend Symbol -> Void)
                                             ('seal -> (List Input-Port Output-Port))))))

(provide make-circuit)