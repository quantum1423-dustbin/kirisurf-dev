#lang typed/racket
(require/typed libkiri/kiss/obfuscation
               (ports->obfs/client (Input-Port Output-Port 
                                               -> (values Input-Port Output-Port)))
               (ports->obfs/server (Input-Port Output-Port
                                               -> (values Input-Port Output-Port))))

(define ports->obfuscated/client ports->obfs/client)
(define ports->obfuscated/server ports->obfs/server)
(provide (all-defined-out))