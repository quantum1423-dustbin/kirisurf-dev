#lang typed/racket
(require libkiri/common)
(require "structs.rkt")


(: run-pipeline-client (#:local-port Integer
                                     #:portgen
                                     (-> (values Input-Port
                                                 Output-Port))
                                     -> TCP-Listener))
(define (run-pipeline-client #:local-port lport
                             #:portgen portgen)
  (debug 4 "Proxy over PIPELINE proxy started")
  
  (define-values (deadin deadout) (make-pipe))
  (close-input-port deadin)
  (close-output-port deadout)
  
  (define-values (qrin qrout) (portgen))
  (: huge-table (HashTable Integer Output-Port))
  (define huge-table (make-hash))
  (: huge-channel (Channelof Any))
  (define huge-channel (make-channel))
  
  (define outstanding-echos (make-atombox 0))
  
  ;; Echo pusher
  (define echthread
    (thread
     (thunk
      (let loop()
        (sleep 4)
        (debug 5 "outstanding echos: ~a" (atomcount outstanding-echos))
        (channel-put huge-channel (echo))
        (atombox-incr! outstanding-echos)
        (loop)))))
  
  ;; obtain a connid
  (: get-connid (-> Integer))
  (define (get-connid)
    (define goo (random 65535))
    (cond
      [(hash-has-key? huge-table goo) (get-connid)]
      [else goo]))
  
  ;; toret
  (: toret TCP-Listener)
  (define toret
    (server-with-dispatch
     "127.0.0.1"
     lport
     (lambda (cin cout)
       (define CONNID (get-connid))
       (with-cleanup (λ() (channel-put huge-channel (close-connection CONNID)))
         (channel-put huge-channel (create-connection CONNID))
         (hash-set! huge-table CONNID cout)
         ;; Now we do the thing
         (let: loop : Void ()
           (define bts (read-bytes-avail cin))
           (cond
             [(eof-object? bts) (void)]
             [else (channel-put huge-channel (data CONNID bts))
                   (loop)]))))))
  
  ;; Upstream
  (: up-thread Thread)
  (define up-thread
    (thread
     (thunk
      (with-cleanup (λ() (debug 5 "OMGGGGG")
                      (for ([bloog (hash->list huge-table)])
                        (close-output-port (cdr bloog)))
                      (close-input-port qrin)
                      (close-output-port qrout)
                      (when (tcp-listener? toret)
                        (tcp-close toret)))
        (let: loop : Void ()
          (define goo (channel-get huge-channel))
          (match goo
            [(close-connection connid) (write-pack (close-connection connid) qrout)
                                       (loop)]
            [(data connid dat) (write-pack (data connid dat) qrout)
                               (loop)]
            [(create-connection connid) (write-pack (create-connection connid) qrout)
                                        (loop)]
            [(echo) (write-pack (echo) qrout)
                    (loop)]
            [_ (error " WTFFFFF")]))))))
  
  
  ;; Downstream
  (: down-thread Thread)
  (define down-thread
    (thread
     (thunk
      (with-cleanup (λ() (debug 5 "WTFFFFF")
                      (for ([bloog (hash->list huge-table)])
                        (close-output-port (cdr bloog)))
                      (close-input-port qrin)
                      (close-output-port qrout)
                      (when (tcp-listener? toret)
                        (tcp-close toret)))
        (let: loop : Void ()
          (with-handlers ([exn:fail? (lambda(x)
                                       (debug 5 "~a" x)
                                       (loop))])
            (define new-pack (read-pack qrin))
            (match new-pack
              [(data connid bts) (write-bytes bts (hash-ref huge-table connid))
                                 (flush-output (hash-ref huge-table connid))
                                 (loop)]
              [(close-connection connid) (close-output-port (hash-ref huge-table connid))
                                         (hash-remove! huge-table connid)
                                         (loop)]
              [(echo) (atombox-decr! outstanding-echos)
                      (loop)]
              [_ (error "WTF")])))))))
  
  toret)


(provide (all-defined-out))