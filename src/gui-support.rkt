#lang racket/gui
(require racket/lazy-require)
(require net/dns)
(require libkiri/common)
(require libkiri/config)
(require "main.rkt")
(require "l10n.rkt")
(lazy-require ("gui.rkt"
               (events/set-status
                draw-data
                events/switch-tpane
                disable-cbutton
                enable-cbutton)))

(define our-lock (make-semaphore 1))

(define CONN-SANDBOX (make-custodian))
(define CSERV #f)

(define (Main)
  (debug 3 "GUI started")
  (events/set-status (l10n 'connecting) 20)
  (define connector-thread
    (thread
     (thunk
      (Refresh-Connection))))
  (for ([i 6])
    (sleep 1)
    (events/set-status (l10n 'connecting)
                       (+ 20 (* 10 i))))
  (thread-wait connector-thread))

(define (Refresh-Connection)
  (semaphore-wait our-lock)
  (when CSERV
    (tcp-close CSERV))
  (custodian-shutdown-all CONN-SANDBOX)
  (set! CONN-SANDBOX (make-custodian))
  (call-in-nested-thread
   (thunk
    (set! CSERV (run-node)))
   CONN-SANDBOX)
  (semaphore-post our-lock))

(define (Close-Connection)
  (semaphore-wait our-lock)
  (when CSERV
    (tcp-close CSERV))
  (custodian-shutdown-all CONN-SANDBOX)
  (set! CONN-SANDBOX (make-custodian))
  (semaphore-post our-lock))

(provide (all-defined-out))