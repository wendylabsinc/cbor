# CBOR

[![Swift](https://github.com/wendylabsinc/cbor/actions/workflows/swift.yml/badge.svg)](https://github.com/wendylabsinc/cbor/actions/workflows/swift.yml)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-macOS%20%7C%20iOS%20%7C%20Linux%20%7C%20Windows-blue.svg)](https://swift.org)

A lightweight, cross-platform Swift implementation of [CBOR (RFC 8949)](https://datatracker.ietf.org/doc/html/rfc8949) encoding and decoding. This package provides a Swift `Codable`-compatible interface for working with CBOR data.

## Features

- Full support for Swift's `Codable` protocol
- Cross-platform compatibility (macOS, iOS, Linux, Windows)
- Efficient encoding and decoding of common Swift types
- Support for nested containers and complex data structures
- Comprehensive error handling
- Zero dependencies

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/wendylabsinc/cbor.git", from: "0.0.3")
]
```

Then add the dependency to your target:

```swift
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["CBOR"]
    )
]
```

## Usage Guide

### Basic Usage with Codable

```swift
import CBOR

// Define your Codable types
struct User: Codable {
    let name: String
    let age: Int
    let isActive: Bool
}

// Encoding
let user = User(name: "Alice", age: 30, isActive: true)
let encoder = CBOREncoder()

do {
    let encoded: Data = try encoder.encode(user)
    // Use encoded CBOR data...
} catch {
    print("Encoding error: \(error)")
}

// Decoding
let decoder = CBORDecoder()
do {
    let decoded = try decoder.decode(User.self, from: encoded)
    print("User: \(decoded.name), Age: \(decoded.age)")
} catch {
    print("Decoding error: \(error)")
}
```

### Working with CBOR Values Directly

```swift
// Create CBOR values
let integer = CBOR.unsignedInt(42)
let text = CBOR.utf8String("Hello")
let array = CBOR.array([.unsignedInt(1), .utf8String("two")])

// Create a CBOR map
let map: CBOR = [
    "key1": .unsignedInt(1),
    "key2": .utf8String("value")
]

// Access values using pattern matching
if case let .utf8String(str) = text {
    print(str) // Prints: "Hello"
}

// Use subscript for arrays and maps
let firstElement = array[.unsignedInt(0)] // Returns .unsignedInt(1)
let value = map[.utf8String("key1")] // Returns .unsignedInt(1)
```

### Working with Collections

```swift
// Arrays
let numbers = [1, 2, 3, 4, 5]
let encodedArray = try encoder.encode(numbers)
let decodedArray = try decoder.decode([Int].self, from: encodedArray)

// Dictionaries
let dict = ["key": "value", "number": "42"]
let encodedDict = try encoder.encode(dict)
let decodedDict = try decoder.decode([String: String].self, from: encodedDict)

// Nested Structures
struct ComplexType: Codable {
    let items: [String]
    let metadata: [String: Int]
    let tags: Set<String>
}

let complex = ComplexType(
    items: ["a", "b", "c"],
    metadata: ["count": 3, "version": 1],
    tags: ["tag1", "tag2"]
)
let encodedComplex = try encoder.encode(complex)
```

### Working with Tagged Values

```swift
// Create a tagged date/time string
let dateString = "2023-01-01T00:00:00Z"
let taggedDate = CBOR.tagged(.standardDateTimeString, .utf8String(dateString))

// Create a tagged bignum
let bignumBytes: [UInt8] = [0xFF, 0xFF, 0xFF, 0xFF]
let taggedBignum = CBOR.tagged(.positiveBignum, .byteString(bignumBytes))

// Encode tagged values
let encoder = CBOREncoder()
let encoded = try encoder.encode(taggedDate)
```

### Error Handling

```swift
do {
    let encoded = try encoder.encode(value)
    let decoded = try decoder.decode(Type.self, from: encoded)
} catch CBORCodingError.decodingError(let message) {
    print("Decoding error: \(message)")
} catch CBORCodingError.encodingError(let message) {
    print("Encoding error: \(message)")
} catch {
    print("Unexpected error: \(error)")
}
```

## Cross-Platform Support

This package is designed to work seamlessly across all platforms that support Swift:

- macOS 10.15+
- iOS 13.0+
- tvOS 13.0+
- watchOS 6.0+
- Linux
- Windows

No platform-specific code or dependencies are used, ensuring consistent behavior across all supported platforms.

# Generating Documentation

This package uses Swift DocC for documentation. You can:

1. View the documentation on [GitHub Pages](https://wendylabsinc.github.io/CBOR/documentation/cbor)

2. Generate documentation locally:
```sh
swift package generate-documentation
```

3. Preview documentation in Xcode:
   - Build the documentation with ⌘ + B
   - Show the documentation navigator with ⌘ + Shift + Ctrl + D

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Credits

Developed and maintained by [Wendy Labs Inc](https://github.com/wendylabsinc).
