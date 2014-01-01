#lang typed/racket
(require libkiri/common)
(require libkiri/config)
(require "structs.rkt")
(require libkiri/port-utils/tokenbucket)

(: run-pipeline-server (-> TCP-Listener))
(define (run-pipeline-server)
  (debug 4 "starting pipeline server")
  (server-with-dispatch
   "127.0.0.1"
   60002
   (lambda (cin cout)
     (: huge-channel (Channelof Any))
     (define huge-channel (make-channel))
     (: huge-table (HashTable Integer Output-Port))
     (define huge-table (make-hash))
     (thread
      (thunk
       (with-cleanup (λ() (channel-put huge-channel 'panic))
         (let: loop : Void ()
           (define hoo (read-pack cin))
           (match hoo
             [(create-connection connid) (assert (not (hash-has-key? huge-table connid)))
                                         (define-values (in rout)
                                           (tcp-connect "localhost"
                                                        (cfg/int 'NextPort)))
                                         (define rin
                                           (port-cascading-limits/in in
                                                                     100
                                                                     50
                                                                     40
                                                                     8))
                                         (hash-set! huge-table connid rout)
                                         (thread
                                          (thunk
                                           (with-cleanup (λ() (close-input-port rin)
                                                           (channel-put huge-channel
                                                                        (close-connection connid)))
                                             (let: sloop : Void ()
                                               (define boo (read-bytes-avail rin))
                                               (cond
                                                 [(eof-object? boo) (void)]
                                                 [else (channel-put huge-channel
                                                                    (data connid boo))
                                                       (sloop)])))))
                                         (loop)]
             [(data connid boo) (write-bytes boo (hash-ref huge-table connid))
                                (flush-output (hash-ref huge-table connid))
                                (loop)]
             [(close-connection connid) (close-output-port
                                         (hash-ref huge-table connid))
                                        (hash-remove! huge-table connid)
                                        (loop)]
             [(echo) (channel-put huge-channel (echo))
                     (loop)]
             [_ (error "Well, yeah.")])))))
     (let loop()
       (define hoo (channel-get huge-channel))
       (match hoo
         [(close-connection connid) (write-pack (close-connection connid)
                                                cout)
                                    (loop)]
         [(data connid boo) (write-pack (data connid boo) cout)
                            (loop)]
         [(echo) (write-pack (echo) cout)
                 (loop)]
         ['panic (void)]
         [x (debug 5 "WTF IS THIS!!! ~a" x) (void)])))))

(provide (all-defined-out))