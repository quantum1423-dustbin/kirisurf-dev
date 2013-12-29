#lang typed/racket
(require libkiri/common)
(require libkiri/nicker)
(require libkiri/config)
(require libkiri/crypto/securedh)
(require libkiri/protocol/multiplex/server)
(require libkiri/protocol/pipeline/server)
(require libkiri/protocol/subcircuit/server)
(require libkiri/kiss/obfuscation)

(: destructor (-> Void))
(define destructor (thunk (debug 3 "Kirisurf safe shutdown complete. Bye.") (void)))


(define (run-node)
  (define my-key 
    (match (with-input-from-file (etc-path "identity.kiridh") read)
      [`(key-pair ,(? exact-integer? private) 
                  ,(? exact-integer? public)) (key-pair private public)]
      [_ (error "Can't read the DH keys!")]))
  (define my-nick (b32hash (number->le (key-pair-public my-key) 512)))
  (match (cfg/sym 'OpMode)
    ['exit-node
     ;; Set up multiplexer
     (define multiplex-server (run-multiplex-server #:next-port 60002))
     ;; Set up pipeliner 
     (define pipeline-server (run-pipeline-server))
     ;; Set up subcircuiter
     (define subcircuit-server (run-subcircuit-server #:port (cfg/int 'NRPort)
                                                      #:exit? #t))
     ;; Now we go report to the huge central server.
     (define-values (rin rout) (obfs-connect "nozomi.mirai.ca" 2380))
     (with-cleanup (λ() (close-input-port rin)
                     (close-output-port rout))
       (write `(add-me-as-server ,my-nick #t) rout)
       (flush-output rout))]
    ['normal-node
     ;; set up subcircuiter
     (define subcircuit-server (run-subcircuit-server #:port (cfg/int 'NRPort)
                                                      #:exit? #f))
     ;; report to central
     (define-values (rin rout) (obfs-connect "nozomi.mirai.ca" 2380))
     (with-cleanup (λ() (close-input-port rin)
                     (close-output-port rout))
       (write `(add-me-as-server ,my-nick #f) rout)
       (flush-output rout))]
    ['silent-exit
     ;; Set up multiplexer
     (define multiplex-server (run-multiplex-server #:next-port 60002))
     ;; Set up pipeliner 
     (define pipeline-server (run-pipeline-server))
     ;; Set up subcircuiter
     (define subcircuit-server (run-subcircuit-server #:port (cfg/int 'NRPort)
                                                      #:exit? #t))
     (void)]
    ['client (void)]
    [_else (error "Invalid operation mode.")])
  ;; Now we set up the client
  (block-forever))

(run-node)