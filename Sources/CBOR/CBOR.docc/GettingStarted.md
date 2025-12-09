# Getting Started

Learn how to use the CBOR library to encode and decode data.

## Overview

This guide walks you through the basics of working with CBOR in Swift, from simple encoding/decoding to using the Codable protocol.

## Installation

Add CBOR to your Swift package dependencies:

```swift
// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "YourProject",
    dependencies: [
        .package(url: "https://github.com/wendylabsinc/cbor", from: "0.7.0")
    ],
    targets: [
        .target(
            name: "YourTarget",
            dependencies: [
                .product(name: "CBOR", package: "cbor")
            ]
        )
    ]
)
```

## Working with CBOR Values

The ``CBOR`` enum represents all possible CBOR values. You can create and encode values directly:

```swift
import CBOR

// Create a CBOR value
let value: CBOR = .unsignedInt(42)

// Encode to bytes
let encoded = value.encode()

// Decode back
let decoded = try CBOR.decode(encoded)
```

### Working with Maps and Arrays

```swift
// Create an array
let array: CBOR = .array([
    .unsignedInt(1),
    .textString("hello"),
    .bool(true)
])

// Create a map
let map: CBOR = .map([
    CBORMapPair(key: .textString("name"), value: .textString("Swift")),
    CBORMapPair(key: .textString("version"), value: .unsignedInt(6))
])
```

## Using Codable

For most applications, you'll want to use Swift's `Codable` protocol with ``CBOREncoder`` and ``CBORDecoder``:

```swift
import CBOR

struct Person: Codable {
    let name: String
    let age: Int
}

// Encode
let encoder = CBOREncoder()
let data = try encoder.encode(Person(name: "Alice", age: 30))

// Decode
let decoder = CBORDecoder()
let person = try decoder.decode(Person.self, from: data)
```

## Memory-Efficient Usage

For embedded systems or when working with large data, use the zero-copy APIs:

```swift
// Access byte strings without copying
if let slice = cbor.byteStringSlice() {
    // Work directly with the slice
    for byte in slice {
        // Process each byte
    }
}

// Iterate arrays without loading all elements
if let iterator = try cbor.arrayIterator() {
    var iter = iterator
    while let element = iter.next() {
        // Process each element
    }
}
```

## Error Handling

The library provides detailed error information through ``CBORError``:

```swift
do {
    let decoded = try CBOR.decode(invalidData)
} catch let error as CBORError {
    switch error {
    case .invalidCBOR:
        print("Invalid CBOR data")
    case .prematureEnd:
        print("Unexpected end of data")
    case .typeMismatch(let expected, let actual):
        print("Expected \(expected), found \(actual)")
    default:
        print("Error: \(error.description)")
    }
}
```
