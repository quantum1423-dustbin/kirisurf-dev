#lang racket

(define (set-system-proxy! port)
  (match (system-type)
    ['unix
     (system 
      (format "unix/set.sh ~a" port))]
    ['macosx
     (system "macosx/start.sh")]
    ['windows
     (system
      (format "windows\\controller.exe set ~a" port))]
    [_ (error "WTF?")]))

(define (clear-system-proxy!)
  (match (system-type)
    ['unix
     (system "unix/unset.sh")]
    ['macosx
     (system "macosx/stop.sh")]
    ['windows
     (system
      (format "windows\\controller.exe unset"))]))

(provide (all-defined-out))