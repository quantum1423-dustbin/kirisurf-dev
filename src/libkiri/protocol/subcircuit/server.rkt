#lang typed/racket
(require libkiri/common)
(require libkiri/protocol/subcircuit/support)
(require libkiri/kiss/obfuscation)
(require libkiri/protocol/directory/frontend)
(require libkiri/protocol/authentication)
(require racket/math)
(require libkiri/config)

(: run-subcircuit-server (#:port Integer #:exit? Boolean -> TCP-Listener))
(define (run-subcircuit-server #:port port
                    #:exit? exit?)
  (obfs-server-with-dispatch
   port
   (lambda (in out)
     (define-values (cin cout) (authenticated-accept in out))
     (match (read-byte cin)
       ;; echo
       [0 (copy-port cin cout)]
       ;; in-network
       [1 (define next-nick-length (eliminate-eof (read-byte cin)))
          (define next-nick (eliminate-eof (read-bytes next-nick-length cin)))
          (debug 5 "next nick is ~a" next-nick)
          (define-values (rhost rport) (node-host 
                                        (string->symbol 
                                         (bytes->string/utf-8 next-nick))))
          (define-values (rin rout) (obfs-connect rhost rport))
          (debug 5 "established next connection to ~a:~a" rhost rport)
          (thread (thunk (scopy-port cin rout)))
          (copy-port rin cout)]
       ;; out-network
       [2 (assert exit?)
          (define-values (rin rout) (tcp-connect "localhost"
                                                 (cfg/int 'multiplex-server-port)))
          (thread (thunk (scopy-port cin rout)))
          (copy-port rin cout)]))))

(provide (all-defined-out))