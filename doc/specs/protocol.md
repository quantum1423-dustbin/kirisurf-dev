# Kirisurf protocol 

The Kirisurf protocol has three layers: the subcircuit layer, the multiplex layer, and the transport layer.

## General network topology

The Kirisurf network is a stereotypical "mesh" network. The central server keeps track of all the metadata about the nodes. This includes location, IP address, public key. With this information, Kirisurf's central directory builds a graph with the following properties:

 - Each node is adjacent to three or more preferably geographically close nodes, unless there are too little nodes.
 - All nodes are adjacent to all exit servers.

Then, each node will have the right to know the IP addresses of all the adjacent nodes. Remaining metadata, including adjacency information, is shared by all nodes.

## Subcircuit layer

The subcircuit layer is very much inspired by Tor, with some major differences.

### Mandatory obfuscation

The mandatory obfuscation is covered in the KiSS protocol spec. However, the rest of KiSS is not used as it is not tested. It may be used in future experimental and even production versions.

### Usage of TLS

TLS is used in the subcircuit layer. Each node knows the public keys of everybody. When connecting, the public key must be verified.

### Commands

The format is as follows:

    enum { echo, in_network, out_network }
    // if in_network
      Byte: length
      Bytes: nick
    // if out_network
      Byte: length
      Bytes: host:port
      
## Multiplex layer

The multiplex layer multiplexes multiple subcircuits into one stream; i.e. it demultiplexes one stream into multiple subcircuits.

To accomplish this role, segments are numbered with a 64-bit counter and 128-bit connection ID. Each segment is of the following format:

    enum { new_connection, close_connection, close_subcircuit, data }
    16 bytes LE: connection ID
    2 bytes LE: length of body
    Bytes: body

### Establishing new connections

The body of a `new_connection` segment is empty.

### Data transfer

The body of a `data` segment is

    8 bytes: counter
    Bytes: body
    
### Closing connections

The body of a `close_connection` segment is ignored.

### Closing subcircuits

Body is ignored. When receiving this segment, the subcircuit should be closed as soon as no data is pending on it.

### Returning data to the client

Everything is the same except for omitting the `new_connection` segment. 