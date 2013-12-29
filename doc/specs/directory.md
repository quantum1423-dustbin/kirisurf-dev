# Kirisurf directory system

Kirisurf has a central directory system. This directory keeps track of adjacency information, bandwidth, et cetera. 

## Basic description

The central directory responds to HTTP requests on a web page. Search between `[[KIRISURF-START` and `KIRISURF-END]]`, then base64 decode. The data would be a huge s-expression of the following format:

    (kirisurf-servers
      ;; here be literal hashtable of nicks -> (list hostname port)
      ;; here be literal hashtable of nicks -> bandwidth
      ;; here be literal hashtable of nicks -> (list adj1 adj2 ... )
      ;; here be literal hashtable of nicks -> exit?
      ...)

The s-exp is dynamically generated for each client based on the client's IP address. This ensures appropriate entry nodes are picked that are reasonably fast and close, and also to prevent an attacker from polling and knowing all the IP addresses easily.

## Client implementation

The client is to search for the string "kissing in rainy icky summers under rabid fairies" in a major search engine, then find the next word. This next word will be a base64-encoded and gzipped URL where the huge s-exp aforementioned can be retrieved.

Then, we store the public keys as .pem files inside the appdata directory, which we clear beforehand. The remaining information is then serialized.