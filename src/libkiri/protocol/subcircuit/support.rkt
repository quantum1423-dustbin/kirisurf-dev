#lang typed/racket
(require libkiri/common)

(struct: packet ((connid : Integer)
                 (length : Integer)
                 (body : Bytes))
  #:transparent)

(define-type Packet packet)

(: make-packet (Integer Bytes -> Packet))
(define (make-packet i b)
  (packet i (bytes-length b) b))

(: read-packet-from-port (Input-Port -> (U EOF Packet)))
(define (read-packet-from-port input)
  (define connid (le->number (eliminate-eof (read-bytes 2 input))))
  (define length (le->number (eliminate-eof (read-bytes 2 input))))
  (define body (eliminate-eof (read-bytes length input)))
  (packet connid length body))

(: write-packet-to-port (Packet Output-Port -> Void))
(define (write-packet-to-port pkt output)
  (write-bytes (number->le (packet-connid pkt) 2) output)
  (write-bytes (number->le (packet-length pkt) 2) output)
  (write-bytes (packet-body pkt) output)
  (void))

(define reference-packet (packet 256 5 #"asdfj"))
(assert (equal? (read-packet-from-port 
                 (open-input-bytes 
                  (with-output-to-bytes 
                      (λ() (write-packet-to-port reference-packet (current-output-port))))))
                reference-packet))

(provide (all-defined-out))