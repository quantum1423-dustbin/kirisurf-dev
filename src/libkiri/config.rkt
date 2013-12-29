#lang typed/racket
(require libkiri/common)

(: config-hash (HashTable Symbol String))
(define config-hash (make-hash))

(define big-lock (make-semaphore 1))

(: refresh-config (-> Void))
(define (refresh-config)
  (with-lock big-lock
  (with-input-from-file
      (etc-path "kirisurf.conf")
    (lambda ()
      (for ([line (in-lines)])
        (match (string-split line ":")
          [(list (? string? key) 
                 (? string? val)) (hash-set! config-hash 
                                             (string->symbol
                                              (string-trim key)) 
                                             (string-trim val))]
          [_ (error "Malformed config line" line)]))))))

(: cfg/str (Symbol -> String))
(define (cfg/str sym)
  (hash-ref config-hash sym))

(: cfg/int (Symbol -> Integer))
(define (cfg/int sym)
  (define blah (string->number (cfg/str sym)))
  (if (exact-integer? blah) blah
      (error "Config type error: expected int, but not int")))

(: cfg/sym (Symbol -> Symbol))
(define (cfg/sym sym)
  (string->symbol (cfg/str sym)))

(refresh-config)

(provide (all-defined-out))