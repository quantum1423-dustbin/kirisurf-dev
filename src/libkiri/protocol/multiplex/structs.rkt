#lang typed/racket
(require libkiri/common)

;; Structs for the multiplexing layer.

(struct: data-segment
  ((connid : Integer)
   (counter : Integer)
   (body : Bytes))
  #:transparent)

(struct: new-connection
  ((connid : Integer))
  #:transparent)

(struct: close-connection
  ((connid : Integer))
  #:transparent)

(struct: close-subcircuit
  ())

(define-type MSegment (U data-segment new-connection close-connection close-subcircuit))

(: read-segment-from-port (Input-Port -> MSegment))
(define (read-segment-from-port in)
  (debug 6 "reading segment from input port")
  (match (read-byte in)
    [0 (define connid (le->number (eliminate-eof (read-bytes 16 in))))
       (debug 6 "connid read")
       (define bodlen (le->number (eliminate-eof (read-bytes 2 in))))
       (debug 6 "bodlength ~a read" bodlen)
       (read-bytes bodlen in)
       (debug 6 "body read")
       (new-connection connid)]
    [1 (define connid (le->number (eliminate-eof (read-bytes 16 in))))
       (define bodlen (le->number (eliminate-eof (read-bytes 2 in))))
       (read-bytes bodlen in)
       (close-connection connid)]
    [2 (define connid (le->number (eliminate-eof (read-bytes 16 in))))
       (define bodlen (le->number (eliminate-eof (read-bytes 2 in))))
       (read-bytes bodlen in)
       (close-subcircuit)]
    [3 (define connid (le->number (eliminate-eof (read-bytes 16 in))))
       (define bodlen (le->number (eliminate-eof (read-bytes 2 in))))
       (define ctr (le->number (eliminate-eof (read-bytes 8 in))))
       (define body (eliminate-eof (read-bytes (- bodlen 8) in)))
       (data-segment connid ctr body)]
    [x (close-subcircuit)]))

(: write-segment-to-port (MSegment Integer Output-Port -> Void))
(define (write-segment-to-port segm connid out)
  (debug 6 "writing segment ~a" segm)
  (match segm
    [(data-segment connid ctr data) (write-byte 3 out)
                                    (write-bytes (number->le connid 16) out)
                             (define bigbody
                               (with-output-to-bytes
                                   (thunk
                                    (write-bytes (number->le ctr 8))
                                    (write-bytes data))))
                             (write-bytes (number->le (bytes-length bigbody) 2) out)
                             (write-bytes bigbody out)]
    [(new-connection connid) (write-byte 0 out)
                             (write-bytes (number->le connid 16) out)
                             (write-byte 0 out)
                             (write-byte 0 out)]
    [(close-connection connid) (write-byte 1 out)
                               (write-bytes (number->le connid 16) out)
                               (write-byte 0 out)
                               (write-byte 0 out)]
    [(close-subcircuit) (write-byte 2 out)
                        (write-bytes (make-bytes 16) out)
                        (write-byte 0 out)
                        (write-byte 0 out)])
  (flush-output out)
  (void))

(provide (all-defined-out))