#lang racket
(require libkiri/crypto/securedh)
(require libkiri/common)
(require libkiri/nicker)

(define our-keys
  (securedh-genpair))

(with-output-to-file
    (etc-path "identity.kiridh")
  (λ() (write `(key-pair ,(key-pair-private our-keys)
                         ,(key-pair-public our-keys))))
  #:exists 'replace)

(with-output-to-file
    (etc-path "kirisurf.conf")
  (λ() (display #"multiplex-server-port : 50002
socks-server-port : 50000
NRPort : 2377
OpMode : silent-exit
NextPort : 8888
MemLimit : 104857600"))
  #:exists 'replace)

(printf "YOUR NICKNAME IS ~a"
        (b32hash (number->le (key-pair-public our-keys) 512)))