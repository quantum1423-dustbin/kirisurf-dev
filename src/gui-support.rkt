#lang racket/gui
(require racket/lazy-require)
(require net/dns)
(require libkiri/common)
(require libkiri/untyped)
(require libkiri/config)
(require libkiri/protocol/pipeline/client)
(require "main.rkt")
(require "l10n.rkt")
(lazy-require ("gui.rkt"
               (events/set-status
                draw-data
                events/switch-tpane
                disable-cbutton
                enable-cbutton
                layout/connection-button
                make-image-button
                img
                set-cbutton-img!)))

(define our-lock (make-semaphore 1))

(define CONN-SANDBOX (make-custodian))
(define CSERV #f)

(define (Main)
  (with-lock/ut our-lock
    (debug 3 "GUI: started")
    
    (events/set-status (l10n 'connecting) 20)
    (define connector-thread
      (thread
       (thunk
        (Refresh-Connection))))
    (for ([i 6])
      (sleep 2)
      (events/set-status (l10n 'connecting)
                         (+ 20 (* 10 i))))
    (thread-wait connector-thread)
    (events/set-status (l10n 'connected) 100)
    (events/switch-tpane 1)
    (thread-resume hoo-thread)
    (debug 3 "GUI: Main done")))


(define BigButtonConnected #t)

(define (callbacks/big-button but evt)
  (thread
   (thunk
    (with-lock/ut our-lock
      (thread-suspend hoo-thread)
      (debug 3 "GUI: big button hit")
      (cond
        [BigButtonConnected (Close-Connection)
                            (set! BigButtonConnected #f)
                            (set-cbutton-img!
                             (make-image-button (img "icons/reconnect.png") 
                                                (l10n 'connect)))
                            (events/set-status (l10n 'disconnected) 0)]
        [else (events/set-status (l10n 'connecting) 20)
              (events/switch-tpane 0)
              (define connector-thread
                (thread
                 (thunk
                  (Refresh-Connection))))
              (for ([i 6])
                (sleep 2)
                (events/set-status (l10n 'connecting)
                                   (+ 20 (* 10 i))))
              (thread-wait connector-thread)
              (events/set-status (l10n 'connected) 100)
              (set! BigButtonConnected #t)
              (set-cbutton-img!
               (make-image-button (img "icons/stop.png") (l10n 'disconnect)))
              (thread-resume hoo-thread)
              (events/switch-tpane 1)])))))


(define (Refresh-Connection)
  (when CSERV
    (tcp-close CSERV)
    (set! CSERV #f))
  (custodian-shutdown-all CONN-SANDBOX)
  (debug 4 "Custodian killed")
  (set! CONN-SANDBOX (make-custodian))
  (parameterize ([current-custodian CONN-SANDBOX])
    (set! CSERV (run-node))))

(define (Close-Connection)
  (when CSERV
    (tcp-close CSERV)
    (set! CSERV #f))
  (custodian-shutdown-all CONN-SANDBOX)
  (set! CONN-SANDBOX (make-custodian)))

(define ulast 0)
(define dlast 0)
(define hoo-thread
  (thread
   (thunk
    (let loop()
      (sleep 2)
      (define upspeed (- (unbox _UPBYTES) ulast))
      (set! ulast (unbox _UPBYTES))
      (define downspeed (- (unbox _DOWNBYTES) dlast))
      (set! dlast (unbox _DOWNBYTES))
      (draw-data (* 0.5 upspeed) (* 0.5 downspeed))
      (loop)))))

(thread-suspend hoo-thread)

(provide (all-defined-out))