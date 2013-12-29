#lang typed/racket
(require libkiri/common)
(require libkiri/nicker)
(require libkiri/protocol/authentication)
(require libkiri/kiss/obfuscation)
(require libkiri/kiss/hashes-typed)

;; Maintains the huge graph.

(define GLOBAL-LOCK (make-semaphore 1))


(: host-table (HashTable Symbol (List String Integer)))
(define host-table (make-hash
                    `((t2nhasmbdlyjqxuj2hap35a2sjp4l2ix4c2nhod2l6yj3mrsx5t
                       . ("planetlab1.dojima.wide.ad.jp" 2377))
                      (kbr7va3sf4v5sg4ezcdqoskx3gmqebw4uskatyyrl2lksutryprb
                       . ("hikari.mirai.ca" 2377))
                      (hn72zoodp7bsgantwrlrtmzpna3u7bpr3gt4nprsa33v7znu6kg
                       . ("planet1.jaist.ac.jp" 2377)))))

(: adjacency-table (HashTable Symbol (Listof Symbol)))
(define adjacency-table (make-hash
                         `((t2nhasmbdlyjqxuj2hap35a2sjp4l2ix4c2nhod2l6yj3mrsx5t 
                            . (kbr7va3sf4v5sg4ezcdqoskx3gmqebw4uskatyyrl2lksutryprb
                               hn72zoodp7bsgantwrlrtmzpna3u7bpr3gt4nprsa33v7znu6kg))
                           (kbr7va3sf4v5sg4ezcdqoskx3gmqebw4uskatyyrl2lksutryprb
                            . (t2nhasmbdlyjqxuj2hap35a2sjp4l2ix4c2nhod2l6yj3mrsx5t
                               hn72zoodp7bsgantwrlrtmzpna3u7bpr3gt4nprsa33v7znu6kg))
                           (hn72zoodp7bsgantwrlrtmzpna3u7bpr3gt4nprsa33v7znu6kg
                            . (t2nhasmbdlyjqxuj2hap35a2sjp4l2ix4c2nhod2l6yj3mrsx5t
                               kbr7va3sf4v5sg4ezcdqoskx3gmqebw4uskatyyrl2lksutryprb)))))

(: exit-table (HashTable Symbol Boolean))
(define exit-table (make-hash
                    `((t2nhasmbdlyjqxuj2hap35a2sjp4l2ix4c2nhod2l6yj3mrsx5t . #t)
                      (kbr7va3sf4v5sg4ezcdqoskx3gmqebw4uskatyyrl2lksutryprb . #t)
                      (ehuann2ov46zke6a4kit2s4moxbanhi5mmtb5ofb6xg5fmg5net . #t))))

(: gen-adjacent-nodes (String -> (Listof Symbol)))
(define (gen-adjacent-nodes ipaddr)
  ;; Get hash of ip
  (define ip-hash (string-ref (symbol->string (b32hash (string->bytes/utf-8 ipaddr))) 0))
  (cond
    [(zero? (hash-count host-table)) empty]
    [else
     ;; Now find all the nicks with the same hash
     (filter (lambda: ((nick : Symbol))
               (or (hash-ref exit-table nick)
                   (equal? ip-hash
                           (string-ref (symbol->string (b32hash 
                                                        (string->bytes/utf-8
                                                         (symbol->string nick)))) 0))))
             (map (λ: ((x : (Pair Symbol (List String Integer))))
                    (car x)) (hash->list host-table)))]))

(: sub-hash (All(a b) ((HashTable a b) (Listof a) -> (HashTable a b))))
(define (sub-hash hsh lst)
  (cond
    [(empty? lst) (hash)]
    [else (hash-set (sub-hash hsh (cdr lst))
                    (car lst)
                    (hash-ref hsh (car lst)))]))

(define listener
  (obfs-server-with-dispatch
   2380
   (lambda (cin cout)
     ;(define-values (cin cout) (authenticated-accept in out))
     (define-values (chost cport) (obfs-address cin))
     (debug 3 "Directory server has client ~a:~a reporting in" chost cport)
     (match (read cin)
       [`(get-info) (debug 3 "~a:~a wants to get info" chost cport)
                    (with-lock GLOBAL-LOCK
                      (define host-hash (sub-hash host-table (gen-adjacent-nodes chost)))
                      (: all-hosts (Listof Symbol))
                      (define all-hosts (symbol-list
                                         (map (λ: ((x : (Pair Symbol (List String Integer)))) 
                                                (car x))
                                              (hash->list host-table))))
                      (for ([host all-hosts])
                        (fprintf cout
                                 "~a:~a:~a:~a:"
                                 host
                                 (if (hash-has-key? host-hash host)
                                     (first (hash-ref host-hash host))
                                     "0.0.0.0")
                                 (if (hash-has-key? host-hash host)
                                     (second (hash-ref host-hash host))
                                     -1)
                                 (if (hash-ref exit-table host)
                                     "true"
                                     "false"))
                        (for ([thing (hash-ref adjacency-table host)])
                          (fprintf cout
                                   "~a:"
                                   thing))
                        (fprintf cout "\n")))]
       
       [`(add-me-as-server ,(? symbol? nick) ,(? boolean? exit?))
        (debug 3 "~a:~a wants to join relays as ~a" chost cport nick)
        (with-lock GLOBAL-LOCK
          (define adjnodes (gen-adjacent-nodes chost))
          (hash-set! host-table
                     nick
                     (list chost cport))
          (hash-set! adjacency-table
                     nick
                     adjnodes)
          (hash-set! exit-table
                     nick
                     exit?)
          (debug 5 "Current nodes: ~a" adjacency-table))]))))

(block-forever)