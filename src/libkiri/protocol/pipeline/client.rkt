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
  
  (define goo (make-semaphore 1))
  
  (thread 
   (thunk
    (let loop()
      (sleep 5)
      (debug 5 "connid hash count: ~a" (hash-count connection-table))
      (loop))))
  
  
  (: big-channel (Channelof Pack))
  (define big-channel (make-channel))
  (: connection-table (HashTable Integer (List Input-Port Output-Port)))
  (define connection-table (make-hash))
  (: table-lookup (Integer -> (values Input-Port Output-Port)))
  (define (table-lookup key)
    (apply values (hash-ref connection-table key)))
  (: reverse-lookup (Input-Port -> Integer))
  (define (reverse-lookup val)
    (cdr (assure-not-false
          (assoc val (map (λ: ((b : (Pair Integer (List Input-Port Output-Port))))
                            (match b
                              [(cons a (list c d)) (cons c a)]))
                          (hash->list connection-table))))))
  
  (: get-connid (-> Integer))
  (define (get-connid)
    (assert (< (hash-count connection-table) 65535))
    (define toret (random 65535))
    (cond
      [(hash-has-key? connection-table toret) (get-connid)]
      [else toret]))
  (: little-lock Semaphore)
  (define little-lock (make-semaphore 1))
  
  
  (: toret TCP-Listener)
  (define toret 
    (server-with-dispatch
     "localhost"
     lport
     (lambda (cin cout)
       (debug 5 "accepted a client")
       
       (debug 5 "connection request to read")
       
       
       ;; Make sure the underlying thing is actually open
       (with-lock goo
         (cond
           [(or (port-closed? qrin)
                (port-closed? qrout))
            (debug 4 "Underlying transport broken! Trying to recover")
            ;; Refresh
            (define-values (nin nout) (portgen))
            (debug 5 "Recovered ~a ~a" nin nout)
            (close-input-port qrin)
            (close-output-port qrout)
            (set! qrin nin)
            (set! qrout nout)]
           [else (void)]))
       
       ;; connid
       (define CONNID (get-connid))
       (hash-set! connection-table CONNID (list cin cout))
       
       (with-lock little-lock
         (write-pack (create-connection CONNID)
                     qrout)
         (debug 5 "pack written"))
       
       (debug 5 "connection established")
       
       ;; Upstream
       (with-cleanup (λ() (hash-remove! connection-table CONNID))
         (let: loop : Void()
           (define blah (read-bytes-avail cin))
           (cond
             [(eof-object? blah) (debug 5 "eof on upstream here")
                                 (with-lock little-lock
                                   (write-pack (close-connection CONNID)
                                               qrout))]
             [else (with-lock little-lock
                     (write-pack (data CONNID blah) qrout))
                   (loop)]))))))
  
  ;; Downstream
  (thread
   (thunk
    (with-cleanup (λ() (close-input-port qrin)
                    (close-output-port qrout))
      (let: loop : Void ()
        (cond
          [(or (port-closed? qrin)
               (port-closed? qrout)) (sleep 1)
                                     (loop)]
          [else 
           (with-handlers ([exn:fail? (λ(x) (pretty-print x)
                                        (close-input-port qrin)
                                        (close-output-port qrout)
                                        (sleep 1)
                                        (loop))])
             (define new-data (read-pack qrin))
             (match new-data
               [(close-connection connid) (when (hash-has-key? connection-table connid)
                                            (define-values (cin cout) (table-lookup connid))
                                            (close-input-port cin)
                                            (close-output-port cout))
                                          (loop)]
               [(data connid body) (when (hash-has-key? connection-table connid)
                                     (define-values (cin cout) (table-lookup connid))
                                     (write-bytes body cout)
                                     (flush-output cout))
                                   (loop)]
               [_ (error "Protocol break.")]))])))))
  
  toret)

(provide (all-defined-out))