#lang typed/racket
(require typed/racket/date)
(require/typed libkiri/untyped
               (_with-timeout (All (a) (Positive-Integer (-> a) -> (U #f a))))
               (_make_input_port
                (Symbol (Bytes -> Integer)
                        False
                        (-> Void) -> Input-Port))
               (_make_output_port
                (Symbol Output-Port
                        (Bytes Integer Integer Boolean Boolean
                               -> Integer)
                        (-> Void) -> Output-Port)))

;imported functions
;(: date->string (





(date-display-format 'iso-8601)

(: with-timeout (All (a) (Positive-Integer (-> a) -> (U #f a))))
(define (with-timeout milli thnk)
  (_with-timeout milli thnk))

(: hash->func (All (a b) ((HashTable a b) -> (a -> b))))
(define (hash->func hsh)
  (lambda (x)
    (hash-ref hsh x)))

(define ref (current-milliseconds))

(: get-time (-> Real))
(define (get-time)
  (/ (current-milliseconds) 1000.0))

(: pad2 (Integer -> String))
(define (pad2 num)
  (cond
    [(< num 10) (format "0~a" num)]
    [else (number->string num)]))

(: get-time-string (-> String))
(define (get-time-string)
  (define date-obj (seconds->date (current-seconds)))
  (format "~a ~a:~a:~a.~a" 
          (date->string (current-date))
          (pad2 (date-hour date-obj))
          (pad2 (date-minute date-obj))
          (pad2 (date-second date-obj))
          (modulo (current-milliseconds) 1000)))

(: scopy-port (case->
               (Input-Port Output-Port -> Void)
               (Input-Port Output-Port (Bytes -> Bytes) -> Void)))
(define (scopy-port in out (chugger identity))
  (dynamic-wind
   void
   (thunk 
    (cond
      ;[(eq? identity chugger) (copy-port in out)]
      [else 
       (define blah (make-bytes 8192))
       (let: scopy-loop : Void ()
         (define c (read-bytes-avail! blah in))
         (cond
           [(procedure? c) (error "WTF?")]
           [(eof-object? c) (close-output-port out)
                            (void)]
           [else (write-bytes (chugger (subbytes blah 0 c)) out)
                 (flush-output out)
                 (scopy-loop)]))]))
   (thunk (close-output-port out)
          (close-input-port in)
          (debug 5 "Closed a port."))))

; Semaphore helper
(define-syntax with-lock
  (syntax-rules ()
    [(_ lck exp1 ...) (with-cleanup (thunk (semaphore-post lck))
                        (semaphore-wait lck)
                        exp1 ...)]))

(define-syntax assert
  (syntax-rules ()
    [(_ exp)
     (if exp (void)
         (error "Assertion failed!" (quote exp)))]))

(: make-dummy (Bytes -> (Bytes -> Bytes)))
(define (make-dummy b)
  identity)

(define DEBUG-LEVEL 5)

;Debug levels:
;1: Usual info, for user to see, such as progress
;2: More detailed info, such as servers found
;3: Internal details, such as tearing down and building up of connections
;4: Diagnostic info involving medium-level function calls
;5: Lowest level function calls and info
(define DEBUG-LOCK (make-semaphore 1))
(: debug (Positive-Integer String Any * -> Void))
(define (debug lvl str . rst)
  (with-lock DEBUG-LOCK
    (when (<= lvl DEBUG-LEVEL)
      (fprintf (current-output-port) "[~a] \tdebug~a: ~a\n" 
               (get-time-string) lvl (apply format `(,str . ,rst))))))

(: number->le (Integer Positive-Integer -> Bytes))
(define (number->le num len)
  
  (: helper (Integer -> (Listof Integer)))
  (define (helper n)
    (cond
      [(zero? n) empty]
      [else (cons (remainder n 256)
                  (helper (quotient n 256)))]))
  (: toret (Listof Integer))
  (define toret (helper num))
  (cond
    [(> (length toret) len) (error "Number too large to encode" num)]
    [else (list->bytes
           (append
            toret
            (make-list (- len (length toret)) 0)))]))

(: le->number (Bytes -> Integer))
(define (le->number le)
  (: helper ((Listof Integer) -> Integer))
  (define (helper le)
    (cond
      [(empty? le) 0]
      [else (+ (car le)
               (* 256 (helper (cdr le))))]))
  (helper (bytes->list le)))

(: be->number (Bytes -> Integer))
(define (be->number be)
  (le->number 
   (list->bytes
    (reverse
     (bytes->list be)))))

(define-syntax-rule (with-cleanup thnk exp1 ...)
  (dynamic-wind
   void
   (thunk exp1 ...)
   thnk))

(define-syntax-rule (wait-until expr)
  (let loop()
    (if expr (void)
        (begin (sleep 0.1)
               (loop)))))

(: randomsel (All (a) ((Listof a) -> a)))
(define (randomsel lst)
  (define rn (random (length lst)))
  (debug 5 "randomly selected index ~a" rn)
  (list-ref lst rn))


(define _EXPOFACTOR 0.3)

(: exposel (All (a) ((Listof a) -> a)))
(define (exposel lst)
  (cond
    [(empty? (cdr lst)) (car lst)]
    [(< (random) _EXPOFACTOR) (car lst)]
    [else (exposel (cdr lst))]))

(define GROUP-16
  #xFFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD129024E088A67CC74020BBEA63B139B22514A08798E3404DDEF9519B3CD3A431B302B0A6DF25F14374FE1356D6D51C245E485B576625E7EC6F44C42E9A637ED6B0BFF5CB6F406B7EDEE386BFB5A899FA5AE9F24117C4B1FE649286651ECE45B3DC2007CB8A163BF0598DA48361C55D39A69163FA8FD24CF5F83655D23DCA3AD961C62F356208552BB9ED529077096966D670C354E4ABC9804F1746C08CA18217C32905E462E36CE3BE39E772C180E86039B2783A2EC07A28FB5C55DF06F4C52C9DE2BCBF6955817183995497CEA956AE515D2261898FA051015728E5A8AAAC42DAD33170D04507A33A85521ABDF1CBA64ECFB850458DBEF0A8AEA71575D060C7DB3970F85A6E1E4C7ABF5AE8CDB0933D71E8C94E04A25619DCEE3D2261AD2EE6BF12FFA06D98A0864D87602733EC86A64521F2B18177B200CBBE117577A615D6C770988C0BAD946E208E24FA074E5AB3143DB5BFCE0FD108E4B82D120A92108011A723C12A787E6D788719A10BDBA5B2699C327186AF4E23C1A946834B6150BDA2583E9CA2AD44CE8DBBBC2DB04DE8EF92E8EFC141FBECAA6287C59474E6BC05D99B2964FA090C3A2233BA186515BE7ED1F612970CEE2D7AFB81BDD762170481CD0069127D5B05AA993B4EA988D8FDDC186FFB7DC90A6C08F4DF435C934063199FFFFFFFFFFFFFFFF)

(define GROUP-5
  #xFFFFFFFFFFFFFFFFC90FDAA22168C234C4C6628B80DC1CD129024E088A67CC74020BBEA63B139B22514A08798E3404DDEF9519B3CD3A431B302B0A6DF25F14374FE1356D6D51C245E485B576625E7EC6F44C42E9A637ED6B0BFF5CB6F406B7EDEE386BFB5A899FA5AE9F24117C4B1FE649286651ECE45B3DC2007CB8A163BF0598DA48361C55D39A69163FA8FD24CF5F83655D23DCA3AD961C62F356208552BB9ED529077096966D670C354E4ABC9804F1746C08CA237327FFFFFFFFFFFFFFFF)

;; function that performs fast modular exponentiation by repeated squaring
(: expt-mod (Integer Integer Integer -> Integer))
(define (expt-mod base exponent modulus)
  (let expt-mod-iter ([b base] [e exponent] [p 1])
    (cond
      [(zero? e) p]
      [(even? e) (expt-mod-iter (modulo (* b b) modulus) (quotient e 2) p)]
      [else (expt-mod-iter b (sub1 e) (modulo (* b p) modulus))])))

; Command substitution function
(: $ (String * -> String))
(define $
  (λ x
    (define args (string-join x " "))
    (with-output-to-string
        (thunk
         (system args)))))

; Read bytes avail
(: read-bytes-avail
   (case->
    (-> (U Bytes EOF))
    (Input-Port -> (U Bytes EOF))))
(define (read-bytes-avail (in (current-input-port)))
  (with-handlers ([exn:fail? (lambda(x) eof)])
    (define buffer (make-bytes 16384))
    (define c (read-bytes-avail! buffer in))
    (cond
      [(eof-object? c) eof]
      [(procedure? c) (error "WTF??????")]
      [else (subbytes buffer 0 c)])))

; GC port
(: gcport (Port -> Port))
(define (gcport prt)
  (define-values (tin tout) (make-pipe 16384))
  (cond
    [(input-port? prt) (thread (thunk (scopy-port prt tout)))
                       tin]
    [(output-port? prt) (thread (thunk (scopy-port tin prt)))
                        tout]))

(: port-ip (Port -> String))
(define (port-ip prt)
  (define-values (a b) (tcp-addresses prt))
  b)



; Assertion of not EOF
(: eliminate-eof (All (a) ((U EOF a) -> a)))
(define (eliminate-eof bts)
  (cond
    [(eof-object? bts) (error "EOF received when not expected")]
    [else bts]))


(: assure-not-false (All(a) ((U a False) -> a)))
(define (assure-not-false x)
  (if x x (error "What? #f? I want to die.")))

;; Returns etc path for something
(: etc-path (String -> String))
(define (etc-path str)
  (string-append "/etc/kirisurf/" str))

;; Generic TCP server thingy
(: server-with-dispatch (String Integer (Input-Port Output-Port -> Void)
                                -> TCP-Listener))
(define (server-with-dispatch host port lmbd)
  (define toret (tcp-listen port 4 #t host))
  (thread
   (thunk
    (let loop()
      (define-values (in out) (tcp-accept toret))
      (thread
       (thunk
        (with-cleanup (λ() (close-input-port in)
                        (close-output-port out))
          (lmbd in out))))
      (loop))))
  toret)

(define-type Chugger (Bytes -> Bytes))

;; Chugger ports
(: chugger-input-port (Chugger Input-Port -> Input-Port))
(define (chugger-input-port chugger inp)
  (define-values (gin gout) (make-pipe 16384))
  (thread (thunk (scopy-port inp gout chugger)))
  gin)

(: chugger-output-port (Chugger Output-Port -> Output-Port))
(define (chugger-output-port chugger out)
  (define-values (gin gout) (make-pipe 16384))
  (thread (thunk (scopy-port gin out chugger)))
  gout)

(: symbol-list ((Listof Any) -> (Listof Symbol)))
(define (symbol-list lst)
  (cond
    [(empty? lst) empty]
    [(symbol? (car lst)) (cons (car lst)
                               (symbol-list (cdr lst)))]
    [else (error "WTF")]))

(: block-forever (-> Void))
(define (block-forever)
  (sleep 1)
  (block-forever))

(: Read-byte (Input-Port -> Integer))
(define (Read-byte inp)
  (eliminate-eof (read-byte inp)))

(: read-to-end (Input-Port -> Bytes))
(define (read-to-end in)
  (define bloo (read-bytes-avail in))
  (cond
    [(eof-object? bloo) #""]
    [else (bytes-append bloo (read-to-end in))]))

(struct: atombox ((count : (Boxof Integer))
                  (lock : Semaphore)))

(: make-atombox (Integer -> atombox))
(define (make-atombox int)
  (atombox (box int) (make-semaphore 1)))

(: atombox-incr! (atombox -> Void))
(define (atombox-incr! bx)
  (with-lock (atombox-lock bx)
    (set-box! (atombox-count bx)
              (add1 (unbox (atombox-count bx))))))

(: atombox-decr! (atombox -> Void))
(define (atombox-decr! bx)
  (with-lock (atombox-lock bx)
    (set-box! (atombox-count bx)
              (sub1 (unbox (atombox-count bx))))))

(: atomcount (atombox -> Integer))
(define (atomcount bx)
  (with-lock (atombox-lock bx)
    (unbox (atombox-count bx))))

(debug 3 "Base library loaded")

(provide (all-defined-out))
