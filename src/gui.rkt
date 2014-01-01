#lang racket/gui
(require "l10n.rkt")
(require framework)
(require "gui-support.rkt")

(define doer-thread
  (thread
   (thunk
    (let loop()
      (define action (thread-receive))
      (action)
      (sleep 0)
      (loop)))))

(define _GLOCK (make-semaphore 1))

(define (RELEASE-GLOCK)
  (semaphore-post _GLOCK))

(define (OBTAIN-GLOCK)
  (semaphore-wait _GLOCK))

;; Buttons with images

(define (make-image-button image text (width (* 4 (send image get-width)))
                           (height (send image get-height)))
  (define the-bitmap (make-bitmap (+ 4 width) (+ 4 height)))
  (define dc (new bitmap-dc% [bitmap the-bitmap]))
  (send dc draw-bitmap
        image
        2
        2)
  (send dc set-font (make-font
                     #:size (if (equal? 'macosx (system-type)) 12 10)
                     #:family 'default))
  (send dc draw-text
        text (+ height 8) (- (/ height 2) 5))
  the-bitmap)



#|
Idea for layout:

|----------------------------------|
|                                  |
|    MAIN CONTROL BUTTONS HERE     |
|                                  |
|----------------------------------|
|                                  |
|                                  |
|                                  |
|   VERY FANCY GRAPH/STATS THINGY  |
|                                  |
|                                  |
|----------------------------------|
|                                  |
|                                  |
|                                  |
|     RETRACTABLE LOGS/SETTINGS    |
|                                  |
|----------------------------------|

|#

(define layout/global-frame 
  (new frame% 
       [label (string-append (l10n 'name)
                             " "
                             (l10n 'version))]
       [min-width 400]
       [min-height 10]
       [stretchable-width #f]
       [stretchable-height #f]
       [alignment '(center top)]))
(send layout/global-frame show #t)

(define layout/padding 
  (new vertical-panel%
       [parent layout/global-frame]
       [horiz-margin 10]
       [vert-margin 10]
       [alignment '(center top)]))

;; Graphics
(define kirilogo
  (make-object bitmap% "./connected.png" 'png/alpha))

(define (img pth)
  (make-object bitmap% pth 'png/alpha))

;; Top status thingy

(define layout/top-pane
  (new group-box-panel%
       [label (l10n 'status)]
       [parent layout/padding]
       [min-height 100]
       [stretchable-height #f]
       [vert-margin 10]))

;; Pane 1 of the status: when loading

(define layout/top-pane/loading
  (new vertical-panel%
       [parent layout/top-pane]
       [alignment '(center center)]))

(define layout/top-pane/loading/status
  (new message%
       [parent layout/top-pane/loading]
       [label "TESTING"]
       [horiz-margin 10]
       [stretchable-width #t]
       [vert-margin 4]))

(define layout/top-pane/loading/progress
  (new gauge%
       [parent layout/top-pane/loading]
       [label ""]
       [range 100]
       [horiz-margin 10]
       [vert-margin 4]))

;; Pane 2 of the status: when finished

(define layout/top-pane/finished
  (new horizontal-panel%
       [parent layout/top-pane]
       [alignment '(center center)]))

(define layout/top-pane/finished/logo
  (new message%
       [parent layout/top-pane/finished]
       [label kirilogo]))

(define layout/top-pane/finished/status
  (new message%
       [parent layout/top-pane/finished]
       [stretchable-width #t]
       [label "TESTING"]))

(define (events/set-status txt (prog #f))
  (gui/do
   (send layout/top-pane/loading/status set-label txt)
   (send layout/top-pane/finished/status set-label txt)
   (when prog
     (send layout/top-pane/loading/progress set-value prog))))

(define (events/switch-tpane num)
  (gui/do
   (if (zero? num)
       (send layout/top-pane change-children
             (λ(c) (list layout/top-pane/loading)))
       (send layout/top-pane change-children
             (λ(c) (list layout/top-pane/finished))))))

(events/switch-tpane 0)

;; Buttons

(define layout/mid-pane
  (new group-box-panel%
       [label (l10n 'actions)]
       [parent layout/padding]
       [vert-margin 10]))

(define layout/mid-pane/thing
  (new vertical-panel%
       [parent layout/mid-pane]))

(define layout/mid-pane/top
  (new horizontal-panel%
       [parent layout/mid-pane/thing]
       [alignment '(center center)]))

(define layout/mid-pane/bottom
  (new horizontal-panel%
       [parent layout/mid-pane/thing]
       [alignment '(center center)]))

(define connected? #t)

(define layout/connection-button
  (new button%
       [parent layout/mid-pane/top]
       [label (make-image-button (img "icons/stop.png") (l10n 'disconnect))]))

(define (disable-cbutton)
  (send layout/connection-button enable #f))

(define (enable-cbutton)
  (send layout/connection-button enable #t))

#|
(define layout/entrynode-button
  (new button%
       [parent layout/mid-pane/top]
       [label (make-image-button (img "icons/entrynode.png") (l10n 'entrynode))]))|#

(define layout/settings-button
  (new button%
       [parent layout/mid-pane/bottom]
       [label (l10n 'settings)]))

(define layout/details-button
  (new button%
       [parent layout/mid-pane/bottom]
       [label (l10n 'details)]))

(define layout/bugs-button
  (new button%
       [parent layout/mid-pane/bottom]
       [label (l10n 'reportbug)]))

;; Statistics canvas

(define _get_drawer_ (λ x (displayln "AAAAAA!") void))
(define layout/stat-canvas
  (new canvas%
       [parent layout/padding]
       [min-width 380]
       [min-height 180]
       [paint-callback (λ(c b) ((_get_drawer_) c b))]))

(define (draw-on-stats cbk)
  (set! _get_drawer_ (thunk cbk))
  (send layout/stat-canvas on-paint))

(define (scale-value vl)
  ((λ(x) (* x x x x)) (log vl)))

(define (speed->height Bps)
  (/ (scale-value (add1 Bps))
     (scale-value (* 1024 1024 2.3))))



;; Draw a datum
(define draw-data
  (let ([down-history empty]
        [up-history empty])
    (λ(down up)
      (set! down-history (cons down down-history))
      (set! up-history (cons up up-history))
      (when (> (length down-history) 80)
        (set! down-history (take down-history 80))
        (set! up-history (take up-history 80)))
      (draw-on-stats
       (λ (cvs drw)
         (send drw suspend-flush)
         (send drw set-smoothing 'smoothed)
         (send drw clear)
         ;Draw the big black background
         (send drw set-brush "black" 'solid)
         (send drw draw-rectangle 0 0 380 180)
         (send drw set-font (make-font
                             #:size 9
                             #:family 'default))
         (send drw set-text-foreground "white")
         
         ;Bps to y-axis value
         (define (speed->yvalue spd)
           (- 180 (* 180 (speed->height spd))))
         
         ;Draw the logarithmic transfer rate lines
         (send drw set-pen "DarkGreen" 2 'solid)
         
         ;2 MiB/s line
         (send drw draw-line
               0 (speed->yvalue (* 2 1024 1024))
               380 (speed->yvalue (* 2 1024 1024)))
         (send drw draw-text
               "2.0 MiB/s" 300 (speed->yvalue (* 2 1024 1024)))
         
         ;1.5 MiB/s line
         (send drw draw-line
               0 (speed->yvalue (* 1.5 1024 1024))
               380 (speed->yvalue (* 1.5 1024 1024)))
         (send drw draw-text
               "1.5 MiB/s" 300 (speed->yvalue (* 1.5 1024 1024)))
         
         ;1.0 MiB/s line
         (send drw draw-line
               0 (speed->yvalue (* 1.0 1024 1024))
               380 (speed->yvalue (* 1.0 1024 1024)))
         (send drw draw-text
               "1.0 MiB/s" 300 (speed->yvalue (* 1.0 1024 1024)))
         
         ;500 KiB/s line
         (send drw draw-line
               0 (speed->yvalue (* 500 1024))
               380 (speed->yvalue (* 500 1024)))
         (send drw draw-text
               "500 KiB/s" 300 (speed->yvalue (* 500 1024)))
         
         ;200 KiB/s line
         (send drw draw-line
               0 (speed->yvalue (* 200 1024))
               380 (speed->yvalue (* 200 1024)))
         (send drw draw-text
               "200 KiB/s" 300 (speed->yvalue (* 200 1024)))
         
         ;50 KiB/s line
         (send drw draw-line
               0 (speed->yvalue (* 50 1024))
               380 (speed->yvalue (* 50 1024)))
         (send drw draw-text
               "50 KiB/s" 300 (speed->yvalue (* 50 1024)))
         
         ;Draw download rates
         (send drw set-pen "Aqua" 1.5 'solid)
         (let down-draw ([offset 0]
                         [pairs (pairify down-history)])
           (match pairs
             [`((,a ,b) . ,rst) (send drw draw-line 
                                      (- 380 offset) (speed->yvalue a)
                                      (- 380 (+ 5 offset))
                                      (speed->yvalue b))
                                (down-draw (+ 5 offset) rst)]
             ['() (void)]))
         
         ;Draw upload rate
         (send drw set-pen "Orange" 1.5 'solid)
         (let up-draw ([offset 0]
                       [pairs (pairify up-history)])
           (match pairs
             [`((,a ,b) . ,rst) (send drw draw-line 
                                      (- 380 offset) (speed->yvalue a)
                                      (- 380 (+ 5 offset))
                                      (speed->yvalue b))
                                (up-draw (+ 5 offset) rst)]
             ['() (void)]))
         (send drw resume-flush)
         )))))

(define (pairify lst)
  (match lst
    [`(,a ,b . ,rst) `((,a ,b) . ,(pairify (cons b rst)))]
    [_ '()]))


(define (test-canvas)
  (define init-d 200000)
  (define init-u 200000)
  (let loop ([d init-d]
             [u init-d])
    (gui/do (draw-data d u))
    (sleep 0.1)
    (loop (* (+ 1 (- (/ (random) 4) 0.125)) d)
          (* (+ 1 (- (/ (random) 4) 0.125)) u))))

(draw-data 0 0)

(define-syntax gui/do
  (syntax-rules ()
    [(_ exp1 ...) (thread-send doer-thread
                               (thunk exp1 ...))]))

(thread Main)

(provide (all-defined-out))