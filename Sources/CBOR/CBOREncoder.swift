import Foundation

/// An error thrown when something goes wrong in CBOR encoding or decoding.
enum CBORCodingError: Error {
    case unsupportedType
    case decodingError(String)
    case encodingError(String)
}

/// A CBOR encoder that encodes Swift types to CBOR format according to [RFC 8949](https://datatracker.ietf.org/doc/html/rfc8949).
///
/// Use `CBOREncoder` to encode instances of data types that conform to ``Encodable`` to CBOR format.
/// The encoder supports all standard Swift types and can be extended to support custom types by implementing
/// the `Encodable` protocol.
///
/// ## Example
/// ```swift
/// struct User: Codable {
///     let name: String
///     let age: Int
/// }
///
/// let user = User(name: "Alice", age: 30)
/// let encoder = CBOREncoder()
///
/// do {
///     let encoded: Data = try encoder.encode(user)
///     // Use encoded CBOR data...
/// } catch {
///     print("Encoding error: \(error)")
/// }
/// ```
public class CBOREncoder {

  public init() {}

  /// Encodes a `Codable` value to CBOR data.
  public func encode<T: Encodable>(_ value: T) throws -> Data {
    let encoder = _CBOREncoder()
    try value.encode(to: encoder)

    let cborValue = try encoder.encodedValue()
    let data = try encodeCBOR(cborValue)
    return data
  }

  // MARK: - Private

  /// Encodes a `CBOR` value into raw bytes (Data).
  /// This is a very minimal implementation of CBOR encoding.
  private func encodeCBOR(_ cbor: CBOR) throws -> Data {
    switch cbor {
    case .unsignedInt(let val):
      // Major type 0
      return encodePositiveUInt(val)
    case .negativeInt(let val):
      // Major type 1
      // In CBOR, negative numbers are stored as ~value (i.e., -1 -> 0x20, -2 -> 0x21, etc.)
      let magnitude = val
      return encodeNegativeUInt(magnitude)
    case .utf8String(let str):
      // Major type 3
      let utf8Data = Data(str.utf8)
      return try encodeIndefiniteLength(majorType: 3, length: utf8Data.count) + utf8Data
    case .byteString(let bytes):
      // Major type 2
      let data = Data(bytes)
      return try encodeIndefiniteLength(majorType: 2, length: data.count) + data
    case .array(let arr):
      // Major type 4
      let encodedItems = try arr.map { try encodeCBOR($0) }.reduce(Data()) { $0 + $1 }
      let header = try encodeIndefiniteLength(majorType: 4, length: arr.count)
      return header + encodedItems
    case .map(let dict):
      // Major type 5
      let encodedPairs = try dict.map { (key, value) -> Data in
        let encodedKey = try encodeCBOR(key)
        let encodedValue = try encodeCBOR(value)
        return encodedKey + encodedValue
      }.reduce(Data()) { $0 + $1 }
      let header = try encodeIndefiniteLength(majorType: 5, length: dict.count)
      return header + encodedPairs
    case .null:
      // Simple value for null is 0xf6
      return Data([0xf6])
    case .boolean(let boolVal):
      // Simple value for true is 0xf5, for false is 0xf4
      return boolVal ? Data([0xf5]) : Data([0xf4])
    case .float(let val):
      // Major type 7, additional info 26 (IEEE 754 Single)
      let bits = val.bitPattern
      return Data([0xfa]) + withUnsafeBytes(of: bits.bigEndian) { Data($0) }
    case .double(let val):
      // Major type 7, additional info 27 (IEEE 754 Double)
      let bits = val.bitPattern
      return Data([0xfb]) + withUnsafeBytes(of: bits.bigEndian) { Data($0) }
    case .half(let val):
      // Major type 7, additional info 25 (IEEE 754 Half)
      let bits = Float(val).bitPattern
      let halfBits = UInt16(bits & 0xFFFF)
      return Data([0xf9]) + withUnsafeBytes(of: halfBits.bigEndian) { Data($0) }
    case .tagged(let tag, let item):
      // Major type 6
      let tagData = encodePositiveUInt(tag.rawValue)
      let itemData = try encodeCBOR(item)
      return tagData + itemData
    case .simple(let val):
      // Major type 7
      return Data([0xe0 + val])
    case .undefined:
      // Simple value for undefined is 0xf7
      return Data([0xf7])
    case .break:
      // Break code is 0xff
      return Data([0xff])
    #if canImport(Foundation)
    case .date(let date):
      // Encode dates as tagged strings (tag 0) or epoch-based (tag 1)
      let timestamp = date.timeIntervalSince1970
      let taggedValue = CBOR.tagged(.epochBasedDateTime, .double(timestamp))
      return try encodeCBOR(taggedValue)
    #endif
    }
  }

  /// Encodes an unsigned integer (major type 0).
  private func encodePositiveUInt(_ value: UInt64) -> Data {
    switch value {
    case 0...23:
      return Data([UInt8(value)])
    case 24...0xFF:
      return Data([0x18, UInt8(value & 0xFF)])
    case 0x100...0xFFFF:
      return Data([0x19, UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF)])
    case 0x10000...0xFFFF_FFFF:
      return Data([
        0x1A,
        UInt8((value >> 24) & 0xFF),
        UInt8((value >> 16) & 0xFF),
        UInt8((value >> 8) & 0xFF),
        UInt8(value & 0xFF),
      ])
    default:
      return Data([
        0x1B,
        UInt8((value >> 56) & 0xFF),
        UInt8((value >> 48) & 0xFF),
        UInt8((value >> 40) & 0xFF),
        UInt8((value >> 32) & 0xFF),
        UInt8((value >> 24) & 0xFF),
        UInt8((value >> 16) & 0xFF),
        UInt8((value >> 8) & 0xFF),
        UInt8(value & 0xFF),
      ])
    }
  }

  /// Encodes a negative integer (major type 1).
  private func encodeNegativeUInt(_ value: UInt64) -> Data {
    // In CBOR, negative integers are encoded as -(n+1)
    // So -1 is encoded as 0, -2 as 1, etc.
    switch value {
    case 0...23:
      return Data([0x20 + UInt8(value)])
    case 24...0xFF:
      return Data([0x38, UInt8(value)])
    case 0x100...0xFFFF:
      return Data([0x39, UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF)])
    case 0x10000...0xFFFF_FFFF:
      return Data([
        0x3A,
        UInt8((value >> 24) & 0xFF),
        UInt8((value >> 16) & 0xFF),
        UInt8((value >> 8) & 0xFF),
        UInt8(value & 0xFF)
      ])
    default:
      return Data([
        0x3B,
        UInt8((value >> 56) & 0xFF),
        UInt8((value >> 48) & 0xFF),
        UInt8((value >> 40) & 0xFF),
        UInt8((value >> 32) & 0xFF),
        UInt8((value >> 24) & 0xFF),
        UInt8((value >> 16) & 0xFF),
        UInt8((value >> 8) & 0xFF),
        UInt8(value & 0xFF)
      ])
    }
  }

  /// Encodes indefinite lengths (for arrays, maps, strings, etc.)
  private func encodeIndefiniteLength(majorType: UInt8, length: Int) throws -> Data {
    switch length {
    case 0...23:
      return Data([majorType << 5 | UInt8(length)])
    case 24...0xFF:
      return Data([(majorType << 5) | 24, UInt8(length)])
    case 0x100...0xFFFF:
      return Data([
        (majorType << 5) | 25,
        UInt8((length >> 8) & 0xFF),
        UInt8(length & 0xFF),
      ])
    case 0x10000...0xFFFF_FFFF:
      return Data([
        (majorType << 5) | 26,
        UInt8((length >> 24) & 0xFF),
        UInt8((length >> 16) & 0xFF),
        UInt8((length >> 8) & 0xFF),
        UInt8(length & 0xFF),
      ])
    default:
      // For simplicity, we won't handle arrays/maps larger than 2^32-1
      throw CBORCodingError.encodingError("Container too large")
    }
  }
}

/// Internal class that implements the Swift `Encoder` protocol.
private class _CBOREncoder: Encoder {
  var codingPath: [CodingKey] = []
  var userInfo: [CodingUserInfoKey: Any] = [:]

  private var container: CBOR = .map([:])  // default root is a map if needed
  private var singleValue: CBOR? = nil
  private var isSingleValueContainer = false

  func encodedValue() throws -> CBOR {
    // If we used a single value container, return that. Otherwise, return `container`.
    if isSingleValueContainer {
      if let singleValue = singleValue {
        return singleValue
      } else {
        throw CBORCodingError.encodingError("No value encoded in single-value container.")
      }
    }
    // If container is empty and we have elements, create an array
    if case .map(let dict) = container, dict.isEmpty {
      // For empty maps, return an empty map instead of an array
      return container
    }
    return container
  }

  func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key: CodingKey {
    let container = CBORKeyedEncodingContainer<Key>(encoder: self)
    return KeyedEncodingContainer(container)
  }

  func unkeyedContainer() -> UnkeyedEncodingContainer {
    isSingleValueContainer = false
    container = .array([])  // Initialize as empty array
    return CBORUnkeyedEncodingContainer(encoder: self)
  }

  func singleValueContainer() -> SingleValueEncodingContainer {
    isSingleValueContainer = true
    return CBORSingleValueEncodingContainer(encoder: self)
  }

  // These functions set the top-level container. If the top-level container
  // is already set to something else, we might overwrite it.
  fileprivate func setContainerValue(_ value: CBOR) {
    if case .array = value {
      container = value
    } else if case .map = value {
      container = value
    } else {
      singleValue = value
    }
  }

  fileprivate func setSingleValue(_ value: CBOR) {
    singleValue = value
  }
}

// MARK: - SingleValueEncodingContainer

private struct CBORSingleValueEncodingContainer: SingleValueEncodingContainer {
  var codingPath: [CodingKey] { encoder.codingPath }
  let encoder: _CBOREncoder

  mutating func encodeNil() throws {
    encoder.setSingleValue(.null)
  }

  mutating func encode(_ value: Bool) throws {
    encoder.setSingleValue(.boolean(value))
  }

  mutating func encode(_ value: String) throws {
    encoder.setSingleValue(.utf8String(value))
  }

  mutating func encode(_ value: Double) throws {
    encoder.setSingleValue(.double(value))
  }

  mutating func encode(_ value: Float) throws {
    encoder.setSingleValue(.float(value))
  }

  mutating func encode(_ value: Int) throws {
    if value == Int.min {
      // Special case for minimum value to avoid overflow
      encoder.setSingleValue(.negativeInt(UInt64(Int.max) + 1))
    } else if value < 0 {
      encoder.setSingleValue(.negativeInt(UInt64(-value - 1)))
    } else {
      encoder.setSingleValue(.unsignedInt(UInt64(value)))
    }
  }

  mutating func encode(_ value: Int8) throws {
    try encode(Int(value))
  }

  mutating func encode(_ value: Int16) throws {
    try encode(Int(value))
  }

  mutating func encode(_ value: Int32) throws {
    try encode(Int(value))
  }

  mutating func encode(_ value: Int64) throws {
    if value == Int64.min {
      // Special case for minimum value to avoid overflow
      encoder.setSingleValue(.negativeInt(UInt64(Int64.max) + 1))
    } else if value < 0 {
      encoder.setSingleValue(.negativeInt(UInt64(-value - 1)))
    } else {
      encoder.setSingleValue(.unsignedInt(UInt64(value)))
    }
  }

  mutating func encode(_ value: UInt) throws {
    encoder.setSingleValue(.unsignedInt(UInt64(value)))
  }

  mutating func encode(_ value: UInt8) throws {
    encoder.setSingleValue(.unsignedInt(UInt64(value)))
  }

  mutating func encode(_ value: UInt16) throws {
    encoder.setSingleValue(.unsignedInt(UInt64(value)))
  }

  mutating func encode(_ value: UInt32) throws {
    encoder.setSingleValue(.unsignedInt(UInt64(value)))
  }

  mutating func encode(_ value: UInt64) throws {
    encoder.setSingleValue(.unsignedInt(value))
  }

  mutating func encode<T>(_ value: T) throws where T: Encodable {
    // If T is a custom Encodable type, let it encode into a new _CBOREncoder
    let nestedEncoder = _CBOREncoder()
    try value.encode(to: nestedEncoder)
    let nestedValue = try nestedEncoder.encodedValue()
    encoder.setSingleValue(nestedValue)
  }
}

// MARK: - UnkeyedEncodingContainer

private struct CBORUnkeyedEncodingContainer: UnkeyedEncodingContainer {
  var codingPath: [CodingKey] { encoder.codingPath }
  let encoder: _CBOREncoder
  var count: Int = 0

  private var elements: [CBOR] = []

  fileprivate init(encoder: _CBOREncoder) {
    self.encoder = encoder
    self.count = 0
    self.elements = []
    encoder.setContainerValue(.array([]))  // Initialize as empty array
  }

  mutating func encodeNil() throws {
    elements.append(.null)
    count += 1
    encoder.setContainerValue(.array(elements))
  }

  mutating func encode(_ value: Bool) throws {
    elements.append(.boolean(value))
    count += 1
    encoder.setContainerValue(.array(elements))
  }

  mutating func encode(_ value: String) throws {
    elements.append(.utf8String(value))
    count += 1
    encoder.setContainerValue(.array(elements))
  }

  mutating func encode(_ value: Double) throws {
    let intValue = Int64(value)
    if Double(intValue) == value {
      // Lossless integer
      if intValue >= 0 {
        elements.append(.unsignedInt(UInt64(intValue)))
      } else {
        elements.append(.negativeInt(UInt64(-intValue - 1)))
      }
    } else {
      // Fallback: store as string
      elements.append(.utf8String(String(value)))
    }
    count += 1
    encoder.setContainerValue(.array(elements))
  }

  mutating func encode(_ value: Float) throws {
    try encode(Double(value))
  }

  mutating func encode(_ value: Int) throws {
    if value == Int.min {
      elements.append(.negativeInt(UInt64(Int.max) + 1))
    } else if value < 0 {
      elements.append(.negativeInt(UInt64(-value - 1)))
    } else {
      elements.append(.unsignedInt(UInt64(value)))
    }
    count += 1
    encoder.setContainerValue(.array(elements))
  }

  mutating func encode(_ value: Int8) throws { try encode(Int(value)) }
  mutating func encode(_ value: Int16) throws { try encode(Int(value)) }
  mutating func encode(_ value: Int32) throws { try encode(Int(value)) }
  mutating func encode(_ value: Int64) throws {
    if value == Int64.min {
      elements.append(.negativeInt(UInt64(Int64.max) + 1))
    } else if value < 0 {
      elements.append(.negativeInt(UInt64(-value - 1)))
    } else {
      elements.append(.unsignedInt(UInt64(value)))
    }
    count += 1
    encoder.setContainerValue(.array(elements))
  }

  mutating func encode(_ value: UInt) throws {
    elements.append(.unsignedInt(UInt64(value)))
    count += 1
    encoder.setContainerValue(.array(elements))
  }

  mutating func encode(_ value: UInt8) throws {
    elements.append(.unsignedInt(UInt64(value)))
    count += 1
    encoder.setContainerValue(.array(elements))
  }

  mutating func encode(_ value: UInt16) throws {
    elements.append(.unsignedInt(UInt64(value)))
    count += 1
    encoder.setContainerValue(.array(elements))
  }

  mutating func encode(_ value: UInt32) throws {
    elements.append(.unsignedInt(UInt64(value)))
    count += 1
    encoder.setContainerValue(.array(elements))
  }

  mutating func encode(_ value: UInt64) throws {
    elements.append(.unsignedInt(value))
    count += 1
    encoder.setContainerValue(.array(elements))
  }

  mutating func encode<T>(_ value: T) throws where T: Encodable {
    let nestedEncoder = _CBOREncoder()
    try value.encode(to: nestedEncoder)
    let nestedValue = try nestedEncoder.encodedValue()
    elements.append(nestedValue)
    count += 1
    encoder.setContainerValue(.array(elements))
  }

  mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type)
    -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey
  {
    let nestedEncoder = _CBOREncoder()
    let container = CBORKeyedEncodingContainer<NestedKey>(encoder: nestedEncoder)
    return KeyedEncodingContainer(container)
  }

  mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
    let nestedEncoder = _CBOREncoder()
    return CBORUnkeyedEncodingContainer(encoder: nestedEncoder)
  }

  mutating func superEncoder() -> Encoder {
    return encoder
  }

  func finalize() -> CBOR {
    return .array(elements)
  }

  func finishedEncoding() {
    encoder.setContainerValue(finalize())
  }

  mutating func endEncoding() {
    finishedEncoding()
  }
}

extension CBORUnkeyedEncodingContainer {
  // Once the container is destroyed, store the array into the encoder's container
  // (unless it's a nested container scenario).
  // In a more robust implementation, you’d structure references differently.
  mutating func done() {
    finishedEncoding()
  }
}

// MARK: - KeyedEncodingContainer

private struct CBORKeyedEncodingContainer<K: CodingKey>: KeyedEncodingContainerProtocol {
  typealias Key = K

  var codingPath: [CodingKey] { encoder.codingPath }
  let encoder: _CBOREncoder

  // Make dictionary mutable
  private var dictionary: [CBOR: CBOR] = [:]

  fileprivate init(encoder: _CBOREncoder) {
    self.encoder = encoder
  }

  // Instead of deinit, use explicit finalization
  private func finalizeContainer() {
    encoder.setContainerValue(.map(dictionary))
  }

  mutating func encodeNil(forKey key: K) throws {
    dictionary[.utf8String(key.stringValue)] = .null
    finalizeContainer()
  }

  mutating func encode(_ value: Bool, forKey key: K) throws {
    dictionary[.utf8String(key.stringValue)] = .boolean(value)
    finalizeContainer()
  }

  mutating func encode(_ value: String, forKey key: K) throws {
    dictionary[.utf8String(key.stringValue)] = .utf8String(value)
    finalizeContainer()
  }

  mutating func encode(_ value: Double, forKey key: K) throws {
    let intValue = Int64(value)
    if Double(intValue) == value {
      // Lossless integer
      if intValue >= 0 {
        dictionary[.utf8String(key.stringValue)] = .unsignedInt(UInt64(intValue))
      } else {
        dictionary[.utf8String(key.stringValue)] = .negativeInt(UInt64(-intValue - 1))
      }
    } else {
      // Fallback: store as string
      dictionary[.utf8String(key.stringValue)] = .utf8String(String(value))
    }
    finalizeContainer()
  }

  mutating func encode(_ value: Float, forKey key: K) throws {
    try encode(Double(value), forKey: key)
  }

  mutating func encode(_ value: Int, forKey key: K) throws {
    if value == Int.min {
      dictionary[.utf8String(key.stringValue)] = .negativeInt(UInt64(Int.max) + 1)
    } else if value < 0 {
      dictionary[.utf8String(key.stringValue)] = .negativeInt(UInt64(-value - 1))
    } else {
      dictionary[.utf8String(key.stringValue)] = .unsignedInt(UInt64(value))
    }
    finalizeContainer()
  }

  mutating func encode(_ value: Int8, forKey key: K) throws {
    try encode(Int(value), forKey: key)
  }

  mutating func encode(_ value: Int16, forKey key: K) throws {
    try encode(Int(value), forKey: key)
  }

  mutating func encode(_ value: Int32, forKey key: K) throws {
    try encode(Int(value), forKey: key)
  }

  mutating func encode(_ value: Int64, forKey key: K) throws {
    if value == Int64.min {
      dictionary[.utf8String(key.stringValue)] = .negativeInt(UInt64(Int64.max) + 1)
    } else if value < 0 {
      dictionary[.utf8String(key.stringValue)] = .negativeInt(UInt64(-value - 1))
    } else {
      dictionary[.utf8String(key.stringValue)] = .unsignedInt(UInt64(value))
    }
    finalizeContainer()
  }

  mutating func encode(_ value: UInt, forKey key: K) throws {
    dictionary[.utf8String(key.stringValue)] = .unsignedInt(UInt64(value))
    finalizeContainer()
  }

  mutating func encode(_ value: UInt8, forKey key: K) throws {
    dictionary[.utf8String(key.stringValue)] = .unsignedInt(UInt64(value))
    finalizeContainer()
  }

  mutating func encode(_ value: UInt16, forKey key: K) throws {
    dictionary[.utf8String(key.stringValue)] = .unsignedInt(UInt64(value))
    finalizeContainer()
  }

  mutating func encode(_ value: UInt32, forKey key: K) throws {
    dictionary[.utf8String(key.stringValue)] = .unsignedInt(UInt64(value))
    finalizeContainer()
  }

  mutating func encode(_ value: UInt64, forKey key: K) throws {
    dictionary[.utf8String(key.stringValue)] = .unsignedInt(value)
    finalizeContainer()
  }

  mutating func encode<T>(_ value: T, forKey key: K) throws where T: Encodable {
    let nestedEncoder = _CBOREncoder()
    try value.encode(to: nestedEncoder)
    let nestedValue = try nestedEncoder.encodedValue()
    dictionary[.utf8String(key.stringValue)] = nestedValue
    encoder.setContainerValue(.map(dictionary))
  }

  mutating func nestedContainer<NestedKey>(
    keyedBy keyType: NestedKey.Type,
    forKey key: K
  ) -> KeyedEncodingContainer<NestedKey> {
    // For brevity, this sample doesn’t handle nested containers extensively.
    let nested = CBORKeyedEncodingContainer<NestedKey>(encoder: encoder)
    return KeyedEncodingContainer(nested)
  }

  mutating func nestedUnkeyedContainer(forKey key: K) -> UnkeyedEncodingContainer {
    return CBORUnkeyedEncodingContainer(encoder: encoder)
  }

  mutating func superEncoder() -> Encoder {
    return encoder
  }

  mutating func superEncoder(forKey key: K) -> Encoder {
    return encoder
  }

  func finalize() -> CBOR {
    return .map(dictionary)
  }

  // Called once container is done encoding
  func finishedEncoding() {
    encoder.setContainerValue(finalize())
  }

  // Ensure finalize is called
  mutating func done() {
    finishedEncoding()
  }
}

extension CBORKeyedEncodingContainer {
  // Once the container is destroyed, store the dictionary into the encoder's container
  mutating func endEncoding() {
    finishedEncoding()
  }
}
