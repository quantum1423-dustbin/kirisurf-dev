#lang typed/racket
(require "structs.rkt")
(require libkiri/common)
(require libkiri/crypto/rng-typed)

(: run-multiplex-client (#:local-port Integer
                                      #:port-spawner (-> (values Input-Port
                                                                 Output-Port))
                                      -> TCP-Listener))
(define (run-multiplex-client #:local-port local-port
                              #:port-spawner port-spawn)
  (debug 4 "started multiplex client at port ~a" local-port)
  (server-with-dispatch
   "localhost"
   local-port
   (lambda (in out)
     (debug 5 "multiplex client accepted two ports")
     (define CONNID (le->number (get-random-bytes 16)))
     (: i->o (HashTable Input-Port Output-Port))
     (define i->o (make-hash))
     (: o->i (HashTable Output-Port Input-Port))
     (define o->i (make-hash))
     (define big-lock (make-semaphore 1))
     (: register-ports! (Input-Port Output-Port -> Void))
     (define (register-ports! in out)
       (with-lock big-lock
         (hash-set! i->o in out)
         (hash-set! o->i out in)))
     (: deregister-from-in! (Input-Port -> Void))
     (define (deregister-from-in! in)
       (with-lock big-lock
         (define out (hash-ref i->o in))
         (hash-remove! i->o in)
         (hash-remove! o->i out)))
     (: deregister-from-out! (Output-Port -> Void))
     (define (deregister-from-out! out)
       (with-lock big-lock
         (define in (hash-ref o->i out))
         (hash-remove! o->i out)
         (hash-remove! i->o in)))
     
     (define (shutdown!)
       (debug 5 "SHUTDOWN")
       (for-each (lambda: ((x : (Pair Input-Port Output-Port)))
                   (close-input-port (car x))
                   (close-output-port (cdr x))
                   (deregister-from-in! (car x)))
                 (hash->list i->o))
       (collect-garbage)
       (collect-garbage)
       (collect-garbage))
     
     (: increment! (-> Void))
     (define (increment!)
       (debug 5 "incrementing a port")
       (define-values (nin nout) (port-spawn))
       (register-ports! nin nout))
     
     (: sin Input-Port)
     (: sout Output-Port)
     (define-values (sin sout) (port-spawn))
     (write-segment-to-port (new-connection CONNID) CONNID sout)
     (register-ports! sin sout)
     (debug 5 "initial ports registered")
     (increment!)
     (increment!)
     (increment!)
     (increment!)
     (increment!)
     
     (: random-ports (-> (values Input-Port Output-Port)))
     (define (random-ports)
       (define pr (cons (current-input-port)
                        (current-output-port)))
       (with-lock big-lock
         (set! pr (randomsel (hash->list i->o)))
         )
       (values (car pr) (cdr pr)))
     
     ;; TODO: incr, decr
     
     (thread
      (thunk
       ;; Upstream thread
       (with-cleanup shutdown!
         (define ctr 0)
         (let: loop : Void ()
           (debug 6 "entering upstream loop")
           (define incoming-data (read-bytes-avail in))
           (debug 6 "got incoming data for upstream")
           (define-values (rin rout) (random-ports))
           (debug 6 "got random ports for upstream")
           (cond
             [(eof-object? incoming-data) (void)]
             [else (write-segment-to-port (data-segment CONNID
                                                        ctr
                                                        incoming-data)
                                          CONNID rout)
                   (flush-output rout)
                   (set! ctr (add1 ctr))
                   (loop)])))))
     
     ;; Downstream part.
     (: segment-queue (HashTable Integer Bytes))
     (define segment-queue (make-hash))
     (: flush-queue (-> Void))
     (define flush-queue
       (let ([expected-ctr 0])
         (lambda ()
           (let: loop : Void ()
             (cond
               [(hash-has-key? segment-queue expected-ctr)
                (write-bytes (hash-ref segment-queue expected-ctr)
                             out)
                (hash-remove! segment-queue expected-ctr)
                (set! expected-ctr (add1 expected-ctr))
                (loop)]
               [else (void)])))))
     
     ;; Event-based thing
     (with-cleanup shutdown!
       (let: loop : Void()
         (: booger MSegment)
         (define booger (data-segment 1 2 #""))
         (define input-to-use
           (apply sync (map (lambda: ((x : (Pair Input-Port
                                                 Output-Port)))
                              (car x)) (hash->list i->o))))
         (set! booger (read-segment-from-port input-to-use))
         (match booger
           [(data-segment connid counter body) (hash-set! segment-queue counter body)
                                               (flush-queue)
                                               (flush-output out)
                                               (loop)]
           [(close-subcircuit) (void)]
           [x (error "WTF" x)]))))))

(define dlah
  (run-multiplex-client #:local-port 44444
                        #:port-spawner (thunk (tcp-connect "localhost" 50002))))

(block-forever)