# KiSS draft specification

Revision 1

----------------------

# TODOS BEFORE DONE!!!

 - Key exchange assumes the hardness of solving for logs in modulo some large prime number. This is unproven, and less commonly assumed than the discrete log problem which involves two numbers. *May* result in a **passive** attack if this problem is not actually hard. It sounds hard though, as exponentiation modulo a large prime number intuitively sounds like an irreversable operation. This needs to be fixed anyway. Possibilities:
  - Hacky possibility: immediately renegotiate using ephemeral keys before Mr. Black Hat gets our shared secret << **This fix implemented**
  - ~~Another possibility: Ditch DH. Use DSA/RSA instead. This may be harder to implement securely though.~~
 - ~~Attackers can exchange the position of two packets. Data will get garbled, but MAC will pass. **BAD** idea! In the very least user gets corrupt info. In the worst idea, some application layer protocol's integrity may depend in a crucial way on the existence of two 4096-bit blocks, and if 8192 bits are nuked, then the security *might* be broken. **Must fix**.~~ *FIXED*
 - ~~Packet reflection attacks. Fix so that HMAC keys are different for both directions. **Must fix**.~~ *FIXED*

----------------------

## Introduction

KiSS (Kirisurf Secure Sockets) provides secure transport for data streams over an unsecured channel. The structure of KiSS is inspired by the popular TLS (Transport Layer Security) protocol, with some adjustments to increase security and decrease unnecessary complexity, making secure implementation, even from the ground up, easy. The name is thus also a pun on the common phrase "Keep It Simple, Stupid". Obfuscation is also mandatory to avoid detection by application-layer firewalls. 

## Goals

The goal of this protocol is to provide protection of confidentiality	, integrity, and authenticity to arbitrary data streams. SHA-512 HMAC is used in this version to provide integrity protection, authenticity protection comes from using the Diffie-Hellman key exchange, and confidentiality comes from the usage of stream ciphers. 

(Note that this and all subsequent KiSS versions will exclusively support XOR-based stream ciphers for the symmetric encryption phase, as such ciphers have easily understood mathematical properties, without the multitude of subtle pitfalls (mostly regarding padding and initialization vectors) of ciphers such as block ciphers in CBC mode. The protocol also assumes encryption is the same process as decryption.)

## Presentation language

### Data types

 - `Integer_N`: an N-bit unsigned binary number, in little-endian order
 - `Blob[N]`: an N-byte blob of data, i.e. a byte array
 - `Blob["..."]`: an blob of data containing the said string in UTF-8 encoding. **NOT** zero-terminated! (i.e. C++ programmers, please do not cast to `string`)
 - `Name : { ... }`: the data elements in `...`, all concatenated together in the order specified, defining a new type "Name".
 - `enum {a, b, ...}`: corresponds to an 8-bit integer enum, starting from zero.
 
### Functions
 - `HMAC(message, key, length)` is the SHA-512 HMAC of `message`, using the key `key`, truncated to `length` bytes long.
 - `HASH(message, length)` is defined to be `HMAC(message, "kiss1", length)`
 - `dencrypt(cipher_state, message)` decrypts/encrypts `message` using the stream cipher state `cipher_state`. Does **not** restore `cipher_state` to its original state; instead, the next invocation will use whatever state the previous invocation left `cipher_state` in.
 - `cipher_setup(cipher_name, key)` sets up a stream cipher state 
 
## KiSS protocol

KiSS is a multi-layer protocol. Streams are divided into segments, encrypted, MAC-ed, and then obfuscated. On the receiving side, the process is reversed.

### Session states

KiSS is a stateful protocol. The following states are kept throughout a session:

 - Server public key
 - Client public key
 - Shared secret
 
We describe the following protocols in this document:
 - Obfuscation protocol
 - Handshake protocol
 - Alert protocol
 - Application data protocol


### Obfuscation layer

The obfuscation layer serves primarily as a means to eliminate traffic fingerprints of the KiSS protocol, in order to fit its usage case of circumvention of censorship. It is not intended to provide cryptographic security against active attackers.

The obfuscation protocol starts with a UniformDH (Ian Goldberg, 2012) key exchange on group 16 from RFC3526, essentially a Diffie-Hellman exchange where the exchange is modified so that the public keys look like random data. The following steps are taken:

 - The client opens a connection to the server.
 - The client picks a private key by randomly generating a 4096-bit number. It is then made even by setting its lowest bit to zero. Let `x` be this key, and let `X=g^x (mod p)`, where `p` is the 4096-bit group 16 modulus from RFC3526, and `g` is the standard generator 2. `X` is the public key, and `x` is the private key.
 - The client then randomly chooses one of `p-X` and `X`, sending it to the server.
 - After receiving the client public key, the server does the same two steps.
 - Both parties derive the shared secret according to the standard Diffie-Hellman protocol.
 - An upstream and downstream key are derived as follows: `upkey = HMAC(shared_secret, "kissobfs-upstream", 16)`, `downkey = HMAC(shared_secret, "kissobfs-downstream", 16)`.
 - RC4 cipher states are set up at both sides: `downstream_state=cipher_setup(RC4, downkey)`, `upstream_state=cipher_setup(RC4, upkey)`.
 - Both parties send the following garbage:

```
Junk : concat {
   Integer_16 length = length(nonce);
   Blob[N] nonce = dencrypt(up/downstream_state, "\0\0\0\0...\0"); //repeated a random amount of time
}

```

 - Both parties read the entirety of the junk and confirm that the nonce does in fact decrypt into a series of nulls. If it does not, then the connection is immediately closed.
 - The obfuscation layer is now set up. The upstream state is used to encode/decode the upstream stream, and the downstream state is used to encode/decode the downstream stream. No padding, MACs, record divisions, or similar structures exist whatsover. They are implemented as the segment layer, encapsulated within the obfuscated layer, treating this obfuscation layer as a transport protocol.

#### Notes:

 - The key pair **must** be chosen randomly and independently for each connection.
 - The client and server are strongly recommended to randomly choose between `p-X` and `X` as the public key sent. A random choice makes the probability distribution of the sent key more uniform; in any case the two values are equivalent in subsequent Diffie-Hellman calculations.


### Segment layer

The segment layer runs over the obfuscation layer. Thus, in this section, "sending" or "receiving" data implicitly means first obfuscating the data and then sending it.

#### Segment format

KiSS splits the encapsulated plaintext stream into segments of at most 65535 bytes long. These segments are the basic unit of data on the segment layer. The data structure of a segment is as follows:

```
Segment : concat {
   enum { handshake, alert, application_data } content_type;
   Blob[32] HMAC;
   Integer_16 length;
   Blob[length] payload;
}
```

`length` stores the length of `payload` in bytes. Thus, `payload` can never exceed `65535` bytes. The HMAC field stores an authenticated hash of the payload. This hash is defined as:
  - `HMAC(payload [+] upcounter, HASH(upstream_key, 64), 32)` for upstream packets
  - `HASH(payload [+] downcounter, HASH(downstream_key, 64), 32)` for downstream packets
where `upstream_key` and `downstream_key` are the upstream and downstream encryption keys as negotiated in the handshake, described in the next section, `upcounter` is the grand total of all records sent upstream, numbered from 0 as a 64-bit counter, and `downcounter` is a similar counter for records sent downstream.

#### Handshake format

The client side initiates the handshake by sending a `Segment` with content type `handshake`. The payload is in the following format:

```
ClientGreeting : concat {
   Blob["ASAK"];
   enum { plain_dh, layered_dh } handshake_mode;
   Integer_8 version_number;
   Blob[512] pubkey;
   Integer_8 cipher_list_length;
   Blob["arcfour128-drop8192:other-cipher:..."] cipher_list;
}
```

`handshake_mode` denotes the way keys are exchanged. In `plain_dh` mode, the server uses a fixed Diffie-Hellman key. In `layered_dh` mode, the fixed server Diffie-Hellman key is used as authentication for a layered anonymous Diffie-Hellman exchange. The latter mode is regarded as more secure, as it provides perfect forward secrecy and does not rely on stronger mathematical hardness assumptions than standard DH. `plain_dh` should be secure and is much faster though. We will detail both schemes below.

##### `plain_dh` handshakes

`version_number` denotes the version number of KiSS. The value for this spec is `0x01`.

`pubkey` is a 4096-bit Diffie-Hellman exponent, based on Group 16 in RFC3526. The public key of the client **must** be securely randomly generated. Otherwise, security is trivially broken, as the shared secret will be constant.

`cipher_list_length` is the length, in bytes, of the cipher list `cipher_list`. `cipher_list` is a semicolon-separated list of stream cipher identifiers. The `arcfour128-drop8192` cipher **must** be supported by servers. This cipher is RC4, with a key truncated from the shared secret (derivation process described later), with the first 8192 bytes of the keystream discarded. Other recommended ciphers are described in the appendix; implementors may add new ciphers as they wish, but `arcfour128-drop8192` must be enabled by the server, so clients may use it for compatibility if they wish. One cipher currently in use in kirisurf is `blowfish512-ofb`.

The server responds with the following format:

```
ServerGreeting : concat {
  Blob["KASA"];
  Blob[512] pubkey;
  Integer_8 selected_cipher_length;
  Blob["..."] selected_cipher;
}
```

Note that the server does not reply with the version number if the version is supported. This is to prevent version downgrade attacks by an active attacker, causing connections to fail rather than become insecure when an attacker attempts to change the version. (All security-improving updates will have trivial changes (like different "magic strings" for calculating hashes) to completely break incompatible versions)

The server `pubkey` need not be randomly generated. How to verify the authenticity of `pubkey` is not in the scope of KiSS. (In Kirisurf itself, the directory server distributes secure hashes of these keys)

`selected_cipher_length` is the length, in bytes, of the name of the selected cipher `selected_cipher`.

The two sides then derive the Diffie-Hellman shared secret. Keys for the agreed-upon cipher are then truncated versions of the first part of this shared secret, HMAC-SHA-512ed with `"kiss1_down"`, `"kiss1_up"` for downstream and upstream:

```
down_key=HMAC(shared_secret, "kiss1_down", key_length);
up_key=HMAC(shared_secret, "kiss1_up", key_length);
```

Note that this implies that ciphers requiring keys larger than 512 bits cannot be used.

Then, the server immediately sends an authenticated application data frame containing the list of ciphers that the client sent. This is very important, as this ensures that a man in the middle cannot force negotiation of weak ciphers.

##### `layered_dh` handshakes

The `layered_dh` handshake proceeds by:
 - First doing a `plain_dh` handshake
 - Then, over the resulting application data layer channel (detailed in next section), do another `plain_dh` handshake but with a randomly chosen server key.
 - The application data layer cipher states are reset to those agreed upon in the layered handshake.
 
##### Notes

Note that we are assuming all along that
 - The greetings are well-formed
 - The server supports the client version number
 - The server supports one of the ciphers the client requests.
 
When an error condition occurs, and also in some other situations, an *alert* may be issued. These alerts are covered in the next section.

#### Alert format

When one side needs to send an alert, it sends a `Segment` with content type `alert`. The payload is in the following format:

```
Alert : concat {
  enum { misc_error, misc_warning, echo, discard, connection_close, version_unsupported, ciphers_unsupported, mac_error } alert_type;
  Integer_8 message_length;
  Blob["...human readable message here..."] human_message;
}
```

`alert_type` enums have the following definitions:
 - `misc_error`: Indicates miscellaneous errors not included in the other categories, such as the server running out of memory, etc. When receiving a `misc_error`, the receiver **must** completely abort the connection. The sender should also abort the connection immediately after sending and flushing this alert.
 - `misc_warning`: Indicates a potential issue with the session, but not a fatal error. `human_message` may be shown to the user, but the connection may remain open. Senders of this warning **must not** assume the connection remains open though; receivers of this message may choose to close the connection if it thinks the warning is serious enough.
 - `echo`: Instructs the recipient to echo `human_message` back in a `discard`-type alert. This is used for measuring latency. A compliant recipient **must** send the reply within 100 milliseconds of receiving the echo message.
 - `discard`: Usually used for replies to echo. This instructs the recipient to process `human_message` but not to do anything to the connection in response. Recipients are free to ignore as many `discard` alerts as they wish.
 - `connection_close`: Closes the connection. This alert **must** be received before the connection is closed for the connection close to be considered clean. Otherwise, applications should display some sort of warning about unclean connection close, as this could indicate an attempt at a truncation attack.
 - `version_unsupported`: Indicates to a client, during a handshake, that the server does not support the KiSS version advertised by the client. The client, and the sender, **must** close the connection immediately. In particular, renegotiating another version is **not** permitted! (This opens the avenue to man-in-the-middle attacks in the event an old version of KiSS is broken)
 - `ciphers_unsupported`: Indicates to a client, during a handshake, that the server does not support any of the ciphers in the client's cipher list. The client, and the sender, **must** close the connection immediately. In particular, renegotiating another cipher is **not** permitted! (This opens the avenue to active attackers forcing the parties to use a weak cipher that the attacker can then break)
 - `mac_error`: Indicates to the receiver that a segment with a mismatching HMAC has been received. This is obviously a fatal error, and both the client, and the sender, **must** close the connection immediately. This alert might not be sent; the underlying transport stream can just be slammed shut.
 
`message_length` is the length, in bytes, of `human_message`. This in particular implies that `human_message` should not be longer than 256 bytes in length.
 
`human_message` is a human-readable message, encoded in UTF-8, describing for users the purpose of the alert. The contents are not specified, and may be empty. Implementations **must not** depend on the contents of `human_message` in making any decisions other than showing some message to the user. In particular, `human_message` should not be abused to convey application-level errors.

##### Notes
 - Alert messages should have correct HMACs for all alerts sent beyond the handshake phase.

#### Application data format

After the handshake, both sides may send application data. An application data segment is a `Segment` with content type `application_data`. 

Application data is of length at most 65535 bytes, although usual sizes are much smaller, in the kilobyte range. The application data payload does not have any particular structure, it is just a segmented stream, incremetally encrypted with the appropriate stream cipher state. Note that the upstream state is used for data traveling from the client to the server, and the downstream state used for data traveling from server to the client.

Application data payloads **must** have the correct HMAC in the HMAC field. Upon receiving a segment with the wrong HMAC, a party **must** send a `mac_error` alert, itself properly authenticated, to the remote end, and immediately hang up the connection.
