#lang typed/racket
(require libkiri/common)
(require libkiri/config)
(require libkiri/port-utils/tokenbucket)
(require "structs.rkt")

(: run-multiplex-server (#:next-port Integer -> TCP-Listener))
(define (run-multiplex-server #:next-port next-port)
  (debug 4 "starting multiplex server, next port ~a" next-port)
  (define BIG-LOCK (make-semaphore 1))
  (: state-table (HashTable Integer (List Thread (Listof (List Input-Port Output-Port)))))
  (define state-table (make-hash))
  (define lookup (hash->func state-table))
  (: destroy! (Integer -> Void))
  (define (destroy! connid)
    (with-lock BIG-LOCK
      (debug 4 "multiplex server destroying connid ~a" connid)
      (assert (hash-has-key? state-table connid))
      (for-each (λ(x) (match x
                        [(list (? input-port? inp) 
                               (? output-port? out)) (close-input-port inp)
                                                     (close-output-port out)]))
                (second (lookup connid)))
      (thread-send (first (lookup connid)) 'die-now)
      (hash-remove! state-table connid))
    
    (collect-garbage)
    (collect-garbage)
    (collect-garbage))
  
  (: forward-ports-to-connid (Input-Port Output-Port Integer -> Void))
  (define (forward-ports-to-connid rinp out cnid)
    (define inp
      (port-cascading-limits/in rinp
                                100
                                50
                                40
                                8))
    (with-lock BIG-LOCK
      (define existing-list (second (lookup cnid)))
      (hash-set! state-table 
                 cnid
                 (list (first (lookup cnid))
                       (cons (list inp out)
                             existing-list))))
    (let loop ()
      (define new-data (read-segment-from-port inp))
      (match new-data
        [(close-subcircuit) (debug 5 "closing a subcircuit")
                            (with-lock BIG-LOCK
                              (define existing-list
                                (second (lookup cnid)))
                              (define new-list
                                (filter (λ(x) (if (list? x) 
                                                  (not (eq? (first x) inp))
                                                  (error "CH"))) existing-list))
                              (cond
                                [(empty? new-list) (thread-send (first (lookup cnid))
                                                                (close-connection cnid))]
                                [else (hash-set! state-table
                                                 cnid
                                                 (list (first (lookup cnid))
                                                       new-list))]))]
        [x (thread-send (first (lookup cnid)) x) (loop)])))
  
  (server-with-dispatch
   "127.0.0.1"
   (cfg/int 'multiplex-server-port)
   (lambda (in out)
     (debug 5 "multiplex server accepted subcircuit")
     (match (read-segment-from-port in)
       [(close-subcircuit) (void)]
       [(data-segment connid counter body) (thread-send (first (lookup connid))
                                                        (data-segment connid counter body))
                                           (forward-ports-to-connid in out connid)]
       [(new-connection connid) (with-lock BIG-LOCK
                                  (debug 5 "multiplex server creating new connid ~a" connid)
                                  ;(assert (not (lookup connid)))
                                  (define control-thread
                                    (thread
                                     (thunk
                                      ;; Random select of return port
                                      (define (obtain-port)
                                        (with-lock BIG-LOCK
                                          (second (randomsel (second (lookup connid))))))
                                      (define-values (grin rout) 
                                        (tcp-connect "localhost" next-port))
                                      (define rin
                                        (port-cascading-limits/in grin
                                                                  800
                                                                  400
                                                                  100
                                                                  20))
                                      ;; Segment queue
                                      (: segment-queue (HashTable Integer Bytes))
                                      (define segment-queue (make-hash))
                                      ;; Flush queue
                                      (define flush-queue
                                        (let ([expected-ctr 0])
                                          (lambda ()
                                            (let: loop : Void ()
                                              (cond
                                                [(hash-has-key? segment-queue expected-ctr)
                                                 (debug 6 "yay, chugging along with ~a"
                                                        expected-ctr)
                                                 (write-bytes (hash-ref segment-queue expected-ctr)
                                                              rout)
                                                 (hash-remove! segment-queue expected-ctr)
                                                 (set! expected-ctr (add1 expected-ctr))
                                                 (loop)]
                                                [else (void)])))))
                                      
                                      ;; Downstream thread.
                                      (thread
                                       (thunk
                                        (with-cleanup (λ() (destroy! connid))
                                          (let: loop : Void ((counter : Integer 0))
                                            (define new-data (read-bytes-avail rin))
                                            (cond
                                              [(eof-object? new-data) (void)]
                                              [else (define packetized 
                                                      (data-segment connid counter new-data))
                                                    (write-segment-to-port packetized
                                                                           connid
                                                                           (obtain-port))
                                                    (loop (add1 counter))])))))
                                      ;; Loop that accepts segments and throws them into hashtable
                                      (let loop ()
                                        (match (thread-receive)
                                          [(data-segment connid counter new-data) 
                                           (debug 5 "multiplex server received segment ~a" counter)
                                           (hash-set! segment-queue
                                                      counter
                                                      new-data)
                                           (flush-queue)
                                           (flush-output rout)
                                           (loop)]
                                          [(close-connection connid)
                                           (destroy! connid)
                                           (loop)]
                                          ['die-now (close-input-port rin)
                                                    (close-output-port rout) (void)]
                                          [x (error "UNEXPECTED SEGMENT IN MULTIPLEX SERVER" x)])))))
                                  (hash-set! state-table connid 
                                             (list control-thread (list (list in out)))))
                                (forward-ports-to-connid in out connid)]
       [x (error "Multiplex server: protocol mismatch" x)]))))

(provide (all-defined-out))