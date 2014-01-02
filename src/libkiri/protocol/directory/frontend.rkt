#lang typed/racket
(require net/base64)
(require libkiri/common)
(require/typed libkiri/crypto/rng
               (get-random (Integer -> Integer)))
(require libkiri/kiss/obfuscation)
(require libkiri/protocol/authentication)
(require racket/math)
(require libkiri/nicker)

(struct: directory-info ((host-table : (HashTable Symbol (List String Integer)))
                         (adjacency-table : (HashTable Symbol (Listof Symbol)))
                         (exit-table : (HashTable Symbol Boolean)))
  #:transparent)

(define _directory_cache (directory-info (make-hash) (make-hash) (make-hash)))
(define _expire_time -1)

(define-type Directory directory-info)

(: obtain-directory (-> Directory))
(define (obtain-directory)
  (set! _expire_time (+ (current-seconds) 3600))
  (define-values (rin rout) (obfs-connect "nozomi.mirai.ca" 2380))
  
  (write '(get-info) rout)
  (flush-output rout)
  
  #|(: raw-data (List Integer
                    (HashTable Symbol (List String Integer))
                    (HashTable Symbol (Listof Symbol))
                    (HashTable Symbol Boolean)))|#
  (define raw-data (bytes->string/utf-8 (read-to-end rin)))
  (define raw-lines (string-split raw-data "\n"))
  (: host-table : (HashTable Symbol (List String Integer)))
  (: adjacency-table : (HashTable Symbol (Listof Symbol)))
  (: exit-table : (HashTable Symbol Boolean))
  (define host-table (make-hash))
  (define adjacency-table (make-hash))
  (define exit-table (make-hash))
  (define raw-lsts
    (map (lambda: ((ln : String))
           (match (string-split ln ":")
             [`(,nick ,ip ,port ,exit? . ,adjs )
              (list (string->symbol nick)
                    ip
                    (exact-floor (real-part
                                  (assure-not-false (string->number port))))
                    (if (equal? exit? "true") #t #f)
                    (map string->symbol adjs))]
             [_ (error "WTF")]))
         raw-lines))
  (for ([ln raw-lsts])
    (match ln
      [(list (? symbol? nick)
             (? string? ip)
             (? exact-integer? port)
             (? boolean? exit?)
             (? list? adjs))
       (when (> port 0) (hash-set! host-table nick (list ip port)))
       (hash-set! adjacency-table nick (symbol-list adjs))
       (hash-set! exit-table nick exit?)]
      [_ (error "OMG")]))
  
  (close-output-port rout)
  (close-input-port rin)
  (directory-info host-table
                  adjacency-table
                  exit-table))



(: refresh-directory! (-> Void))
(define (refresh-directory!)
  (cond
    [(> (current-seconds) _expire_time) (set! _directory_cache (obtain-directory))]
    [else (void)]))

(: known-nodes (-> (Listof Symbol)))
(define (known-nodes)
  (refresh-directory!)
  (map (λ: ((x : (List Symbol Any Any))) (car x))
       (hash->list (directory-info-host-table _directory_cache))))

(: node-host (Symbol -> (values String Integer)))
(define (node-host node)
  (refresh-directory!)
  (define toret (hash-ref (directory-info-host-table _directory_cache) node))
  (values (car toret) (cadr toret)))

(: node-authenticator (Symbol -> (Bytes -> Boolean)))
(define (node-authenticator nick)
  (lambda (bts)
    (equal? (b32hash bts) nick)))

(: adjacent-nodes (Symbol -> (Listof Symbol)))
(define (adjacent-nodes node)
  (refresh-directory!)
  (hash-ref (directory-info-adjacency-table _directory_cache) node))

(: find-path (Directory ((Listof Symbol) -> Symbol)
                        -> (Listof Symbol)))
(define (find-path directory selector)
  (define host-table (directory-info-host-table directory))
  (define adjacency-table (directory-info-adjacency-table directory))
  (define exit-table (directory-info-exit-table directory))
  (define known? (hash->func host-table))
  (define exit? (hash->func exit-table))
  (define get-adjacent (hash->func adjacency-table))
  
  ;; Define a helper function; takes accumulator
  (: auxiliary (Symbol (Listof Symbol) -> (Listof Symbol)))
  (define (auxiliary current history)
    (debug 5 "building circuit path at ~a" (cons current history))
    (cond
      ;; If current is viable exit, and 1/2 dice roll, then now is the time
      ;; Another case: path length too long (> 5)
      [(and (exit? current)
            (or (and (< (get-random 100) 50)
                     (>= (length history) 2))
                (> (length history) 5))) (reverse (cons current history))]
      ;; Otherwise, we extend the path.
      [else (define adjacent-nodes (get-adjacent current))
            (debug 5 "~a is adjacent to ~a" current adjacent-nodes)
            ;; We need to filter out nodes we have already visited. Stupid cycle is stupid.
            (define viable-nexts (filter (λ: ((x : Symbol))
                                           (not (member x (cons current history)))) adjacent-nodes))
            ;; If all neighbors are already visited, abort or stop, depending on path length
            (cond
              [(empty? viable-nexts) (cond
                                       [(and (exit? current)
                                             (>= (length history) 2))
                                        (reverse (cons current history))]
                                       [else (define next-node (selector adjacent-nodes))
                                             (auxiliary next-node (cons current history))])]
              [else 
               ;; Then we select our next node.
               (define next-node (selector viable-nexts))
               (auxiliary next-node (cons current history))])]))
  
  ;; We find the entry node randomly. The bandwidth/location mess for *that* one is directory's job
  (: start-node Symbol)
  (define start-node (car (randomsel (hash->list host-table))))
  (auxiliary start-node empty))

(define (get-server-path)
  (refresh-directory!)
  (find-path _directory_cache randomsel))

(provide (all-defined-out))