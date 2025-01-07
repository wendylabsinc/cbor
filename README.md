# CBOR

[![Swift](https://github.com/wendylabsinc/cbor/actions/workflows/swift.yml/badge.svg)](https://github.com/wendylabsinc/cbor/actions/workflows/swift.yml)

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
    .package(url: "https://github.com/wendylabsinc/cbor.git", from: "0.0.1")
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

## Quick Start

### Basic Usage

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

### Working with Collections

```swift
// Arrays
let numbers = [1, 2, 3, 4, 5]
let encodedArray = try encoder.encode(numbers)

// Dictionaries
let dict = ["key": "value", "number": "42"]
let encodedDict = try encoder.encode(dict)

// Nested Structures
struct ComplexType: Codable {
    let items: [String]
    let metadata: [String: Int]
}

let complex = ComplexType(
    items: ["a", "b", "c"],
    metadata: ["count": 3, "version": 1]
)
let encodedComplex = try encoder.encode(complex)
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

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Credits

Developed and maintained by [Wendy Labs Inc](https://github.com/wendylabsinc).
