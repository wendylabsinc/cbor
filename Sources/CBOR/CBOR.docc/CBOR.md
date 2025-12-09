# ``CBOR``

A lightweight, memory-efficient CBOR (Concise Binary Object Representation) implementation for Swift.

## Overview

CBOR is a binary data serialization format defined in [RFC 7049](https://tools.ietf.org/html/rfc7049). This library provides a complete Swift implementation with a focus on memory efficiency, making it ideal for embedded systems and resource-constrained environments.

### Key Features

- **Direct CBOR Data Model**: Represent CBOR values using an enum with cases for all CBOR types
- **Memory-Optimized for Embedded Swift**: Uses `ArraySlice<UInt8>` internally to avoid heap allocations
- **Full Codable Support**: Seamless integration with Swift's `Codable` protocol
- **Cross-Platform**: Works on macOS, Linux, Windows, iOS, tvOS, watchOS, and Android
- **Swift 6.2 Span Support**: Optional zero-copy APIs using the new `Span` type

## Topics

### Essentials

- <doc:GettingStarted>
- ``CBOR``
- ``CBORMapPair``

### Encoding and Decoding

- ``CBOREncoder``
- ``CBORDecoder``

### Error Handling

- ``CBORError``

### Memory-Efficient Iteration

- ``CBORArrayIterator``
- ``CBORMapIterator``
