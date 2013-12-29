#lang typed/racket
(require libkiri/common)
(require "structs.rkt")


(: run-pipeline-client (#:local-port Integer
                                     #:remote-host String
                                     #:remote-port Integer
                                     -> TCP-Listener))
(define (run-pipeline-client #:local-port lport
                             #:remote-host rhost
                             #:remote-port rport)
  (debug 4 "SOCKS over PIPELINE proxy started")
  
  
  (define-values (qrin qrout) (tcp-connect rhost
                                           rport))
  
  
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
       ;; parse initial socks
       (define socks-version (Read-byte cin))
       (assert (= 5 socks-version)) ; Only supports SOCKS5
       (define auth-length (Read-byte cin))
       (read-bytes auth-length cin) ; throw away the authentication method list
       (debug 6 "client socks greeting read")
       
       ;; send our socks back
       (write-byte 5 cout) ; SOCKS 5
       (write-byte 0 cout) ; No authentication
       (flush-output cout)
       (debug 6 "our socks greeting sent")
       
       ;; Read the connection request
       (assert (= 5 (Read-byte cin))) ; Socks must be version 5
       (assert (= 1 (Read-byte cin))) ; Socks request type must be tcp connection
       (assert (= 0 (Read-byte cin))) ; Reserved null
       (define retthing #"")
       (define-values (rhost rport)
         (match (read-byte cin)
           ; IP address
           [1 (define ip1 (Read-byte cin))
              (define ip2 (Read-byte cin))
              (define ip3 (Read-byte cin))
              (define ip4 (Read-byte cin))
              (define ipstring (format "~a.~a.~a.~a"
                                       ip1 ip2 ip3 ip4))
              ;; port number
              (define blah (eliminate-eof (read-bytes 2 cin)))
              (define portnum (be->number blah))
              (set! retthing (bytes-append (bytes 1 ip1 ip2 ip3 ip4) blah))
              (values ipstring portnum)]
           [3 (define namelen (Read-byte cin))
              (define fullname (bytes->string/utf-8 (eliminate-eof (read-bytes namelen cin))))
              (define blah (eliminate-eof (read-bytes 2 cin)))
              (define portnum (be->number blah))
              (set! retthing (bytes-append (bytes 3 namelen)
                                           (string->bytes/utf-8 fullname)
                                           blah))
              (values fullname portnum)]
           [4 (error "IPv6 requested, can't support")]))
       
       (debug 5 "connection request to ~a:~a read" rhost rport)
       
       ;; respond
       (write-byte 5 cout)
       (write-byte 0 cout)
       (write-byte 0 cout)
       (write-bytes retthing cout)
       (flush-output cout)
       
       (debug 5 "connection established")
       
       ;; connid
       (define CONNID (get-connid))
       (hash-set! connection-table CONNID (list cin cout))
       
       (with-lock little-lock
         (write-pack (create-connection CONNID rhost rport)
                     qrout))
       
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
                    (close-output-port qrout)
                    (tcp-close toret))
      (let: loop : Void ()
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
          [_ (error "Protocol break.")])))))
  
  toret)

(define bloo 
  (run-pipeline-client #:local-port 44444
                       #:remote-host "localhost"
                       #:remote-port 60002))

(block-forever)