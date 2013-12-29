#lang racket
;;; A naive queue for thread scheduling.
;;; It holds a list of continuations "waiting to run".

(define *queue* '())

(define (empty-queue?)
  (null? *queue*))

(define (enqueue x)
  (set! *queue* (append *queue* (list x))))

(define (dequeue)
  (let ((x (car *queue*)))
    (set! *queue* (cdr *queue*))
    x))

;;; This starts a new thread running (proc).

(define (fork proc)
  (call/cc
   (lambda (k)
     (enqueue k)
     (proc))))

;;; This yields the processor to another thread, if there is one.

(define (yield)
  (call/cc
   (lambda (k)
     (enqueue k)
     ((dequeue)))))

;;; This terminates the current thread, or the entire program
;;; if there are no other threads left.

(define (thread-exit)
  (if (empty-queue?)
      (exit)
      ((dequeue))))

(define (make-printer name)
  (lambda ()
   (let loop ([n 0])
     (printf "~a says ~a\n" name n)
     (yield)
     (yield)
     (loop (add1 n)))))

(define t1 (make-printer "takaki"))
(define t2 (make-printer "akari"))
(fork t1)
(fork t2)
(thread-exit)