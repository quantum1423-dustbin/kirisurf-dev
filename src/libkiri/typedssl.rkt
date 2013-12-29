#lang typed/racket
(require/typed openssl
               (#:opaque SSL-Server-Context ssl-server-context?)
               (#:opaque SSL-Client-Context ssl-client-context?)
               (ssl-make-client-context (Symbol -> SSL-Client-Context))
               (ssl-make-server-context (Symbol -> SSL-Server-Context))
               (ports->ssl-ports
                (Input-Port Output-Port 
                            #:mode Symbol
                            #:context (U SSL-Client-Context
                                         SSL-Server-Context)
                            #:close-original? Boolean
                            -> (values Input-Port
                                       Output-Port)))
               (ssl-set-ciphers!
                ((U SSL-Client-Context
                    SSL-Server-Context) String -> Void))
               (ssl-set-verify!
                ((U SSL-Client-Context
                    SSL-Server-Context) Boolean -> Void))
               (ssl-load-verify-source!
                ((U SSL-Client-Context
                    SSL-Server-Context) String -> Void))
               (ssl-load-certificate-chain!
                ((U SSL-Client-Context
                    SSL-Server-Context) String -> Void))
               (ssl-load-private-key!
                ((U SSL-Client-Context
                    SSL-Server-Context) String -> Void))
               (ssl-connect
                (String Integer -> (values Input-Port Output-Port))))

(provide ssl-make-client-context
         ssl-make-server-context
         ports->ssl-ports
         ssl-set-ciphers!
         ssl-set-verify!
         ssl-load-verify-source!
         ssl-load-certificate-chain!
         ssl-load-private-key!
         ssl-connect)