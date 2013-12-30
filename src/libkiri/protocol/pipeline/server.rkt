#lang typed/racket
(require libkiri/common)
(require libkiri/config)
(require "structs.rkt")

(: run-pipeline-server (-> TCP-Listener))
(define (run-pipeline-server)
  (debug 4 "starting pipeline server")
  (server-with-dispatch
   "127.0.0.1"
   60002
   (lambda (cin cout)
     (debug 5 "client accepted")
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
     
     (define the-lock (make-semaphore 1))
     
     ;; Upstream thread
     (let: loop : Void ()
       (define blah (read-pack cin))
       (debug 6 "pack read: ~a" blah)
       (match blah
         [(create-connection connid)
          (debug 5 "received request to open connection")
          (thread
           (thunk
            (define-values (rin rout) (tcp-connect "localhost" (cfg/int 'NextPort)))
            (hash-set! connection-table connid (list rin rout))
            ;; downstream part
            (with-cleanup (λ() (close-input-port rin) (close-output-port rout))
              (let: innerloop : Void ()
                (define blah (read-bytes-avail rin))
                (debug 6 "pack prepared for send: ~a" blah)
                (cond
                  [(eof-object? blah) (with-lock the-lock
                                        (write-pack (close-connection connid) cout)
                                        (close-input-port rin)
                                        (close-output-port rout)
                                        (hash-remove! connection-table connid))]
                  [else (with-lock the-lock
                          (write-pack (data connid blah) cout))
                        (innerloop)])))))
          (loop)]
         [(close-connection connid)
          (when (hash-has-key? connection-table connid)
            (define-values (rin rout) (table-lookup connid))
            (close-input-port rin)
            (close-output-port rout)
            (hash-remove! connection-table connid))
          (loop)]
         [(data connid body)
          (when (hash-has-key? connection-table connid)
            (define-values (rin rout) (table-lookup connid))
            (write-bytes body rout)
            (flush-output rout))
          (loop)]
         [(echo)
          (with-lock the-lock
            (write-pack (echo) cout))])))))

(provide (all-defined-out))