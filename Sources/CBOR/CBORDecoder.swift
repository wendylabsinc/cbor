import Foundation

/// A minimal CBOR decoder that can decode common Swift `Codable` types.
public class CBORDecoder {
    
    public init() {}
    
    /// Decodes a `Codable` type from CBOR data.
    public func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let cborValue = try decodeCBOR(data)
        let decoder = _CBORDecoder(cborValue: cborValue)
        return try T(from: decoder)
    }
    
    // MARK: - Private
    
    /// Decodes raw Data into a `CBOR` enum.
    /// Minimal implementation for demonstration purposes.
    private func decodeCBOR(_ data: Data) throws -> CBOR {
        var iterator = data.makeIterator()
        return try parseItem(&iterator)
    }
    
    /// Recursively parse CBOR items.
    private func parseItem(_ it: inout Data.Iterator) throws -> CBOR {
        guard let first = it.next() else {
            throw CBORCodingError.decodingError("Unexpected end of data")
        }
        
        let majorType = first >> 5
        let additionalInfo = first & 0x1F
        
        switch majorType {
        case 0: // positive int
            let value = try parseUInt(additionalInfo, &it)
            return .unsignedInt(value)
        case 1: // negative int
            let value = try parseUInt(additionalInfo, &it)
            // negative ints in cbor are -1 - n
            return .negativeInt(-1 - Int64(value))
        case 2: // byte string
            let length = try parseUInt(additionalInfo, &it)
            let bytes = try parseBytes(Int(length), &it)
            return .byteString(bytes)
        case 3: // text string
            let length = try parseUInt(additionalInfo, &it)
            let bytes = try parseBytes(Int(length), &it)
            guard let str = String(data: bytes, encoding: .utf8) else {
                throw CBORCodingError.decodingError("Invalid UTF-8 string")
            }
            return .utf8String(str)
        case 4: // array
            let length = try parseUInt(additionalInfo, &it)
            var arr: [CBOR] = []
            for _ in 0..<length {
                let element = try parseItem(&it)
                arr.append(element)
            }
            return .array(arr)
        case 5: // map
            let length = try parseUInt(additionalInfo, &it)
            var dict: [CBOR : CBOR] = [:]
            for _ in 0..<length {
                let key = try parseItem(&it)
                let value = try parseItem(&it)
                dict[key] = value
            }
            return .map(dict)
        case 6: // tag
            // Skip tags in this minimal implementation. 
            // Just parse the next item as a normal item.
            _ = try parseUInt(additionalInfo, &it) // skip tag
            return try parseItem(&it)
        case 7: // simple / float / bool / null
            switch additionalInfo {
            case 20: return .bool(false)
            case 21: return .bool(true)
            case 22: return .null
            // Proper float/double handling omitted for brevity
            default:
                throw CBORCodingError.decodingError("Unsupported simple or float type: \(additionalInfo)")
            }
        default:
            throw CBORCodingError.decodingError("Unknown major type: \(majorType)")
        }
    }
    
    /// Parses a length (UInt64) based on additionalInfo.
    private func parseUInt(_ ai: UInt8, _ it: inout Data.Iterator) throws -> UInt64 {
        switch ai {
        case 0...23:
            return UInt64(ai)
        case 24:
            guard let b = it.next() else { throw CBORCodingError.decodingError("Unexpected end of data") }
            return UInt64(b)
        case 25:
            let bytes = try parseBytes(2, &it)
            return bytes.withUnsafeBytes { ptr in
                let aligned = ptr.baseAddress!.assumingMemoryBound(to: UInt8.self)
                return UInt64((UInt16(aligned[0]) << 8) | UInt16(aligned[1]))
            }
        case 26:
            let bytes = try parseBytes(4, &it)
            return bytes.withUnsafeBytes { ptr in
                let aligned = ptr.baseAddress!.assumingMemoryBound(to: UInt8.self)
                return UInt64(UInt32(aligned[0]) << 24 |
                            UInt32(aligned[1]) << 16 |
                            UInt32(aligned[2]) << 8  |
                            UInt32(aligned[3]))
            }
        case 27:
            let bytes = try parseBytes(8, &it)
            return bytes.withUnsafeBytes { ptr in
                let aligned = ptr.baseAddress!.assumingMemoryBound(to: UInt8.self)
                return UInt64(aligned[0]) << 56 |
                       UInt64(aligned[1]) << 48 |
                       UInt64(aligned[2]) << 40 |
                       UInt64(aligned[3]) << 32 |
                       UInt64(aligned[4]) << 24 |
                       UInt64(aligned[5]) << 16 |
                       UInt64(aligned[6]) << 8  |
                       UInt64(aligned[7])
            }
        default:
            throw CBORCodingError.decodingError("Invalid additionalInfo: \(ai)")
        }
    }
    
    /// Parses `count` bytes from the iterator.
    private func parseBytes(_ count: Int, _ it: inout Data.Iterator) throws -> Data {
        var buffer = [UInt8]()
        for _ in 0..<count {
            guard let byte = it.next() else {
                throw CBORCodingError.decodingError("Unexpected end of data")
            }
            buffer.append(byte)
        }
        return Data(buffer)
    }
}

/// Internal CBOR decoder that implements the Swift `Decoder` protocol.
fileprivate class _CBORDecoder: Decoder {
    var codingPath: [CodingKey] = []
    var userInfo: [CodingUserInfoKey : Any] = [:]
    
    let cborValue: CBOR
    
    init(cborValue: CBOR) {
        self.cborValue = cborValue
    }
    
    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
        guard case let .map(dict) = cborValue else {
            throw CBORCodingError.decodingError("Expected CBOR map")
        }
        
        let container = CBORKeyedDecodingContainer<Key>(decoder: self, dictionary: dict)
        return KeyedDecodingContainer(container)
    }
    
    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        guard case let .array(arr) = cborValue else {
            throw CBORCodingError.decodingError("Expected CBOR array")
        }
        return CBORUnkeyedDecodingContainer(decoder: self, array: arr)
    }
    
    func singleValueContainer() throws -> SingleValueDecodingContainer {
        return CBORSingleValueDecodingContainer(decoder: self, value: cborValue)
    }
}

// MARK: - SingleValueDecodingContainer

fileprivate struct CBORSingleValueDecodingContainer: SingleValueDecodingContainer {
    var codingPath: [CodingKey] { decoder.codingPath }
    let decoder: _CBORDecoder
    let value: CBOR
    
    init(decoder: _CBORDecoder, value: CBOR) {
        self.decoder = decoder
        self.value = value
    }
    
    func decodeNil() -> Bool {
        if case .null = value {
            return true
        }
        return false
    }
    
    func decode(_ type: Bool.Type) throws -> Bool {
        guard case let .bool(b) = value else {
            throw CBORCodingError.decodingError("Expected bool")
        }
        return b
    }
    
    func decode(_ type: String.Type) throws -> String {
        switch value {
        case .utf8String(let str): return str
        case .unsignedInt(let num): return String(num)
        case .negativeInt(let num): return String(num)
        default:
            throw CBORCodingError.decodingError("Expected string")
        }
    }
    
    func decode(_ type: Double.Type) throws -> Double {
        switch value {
        case .unsignedInt(let num): return Double(num)
        case .negativeInt(let num): return Double(num)
        case .utf8String(let str):
            guard let d = Double(str) else {
                throw CBORCodingError.decodingError("Invalid double format in string")
            }
            return d
        default:
            throw CBORCodingError.decodingError("Expected a numeric type for Double")
        }
    }
    
    func decode(_ type: Float.Type) throws -> Float {
        return Float(try decode(Double.self))
    }
    
    func decode(_ type: Int.Type) throws -> Int {
        switch value {
        case .unsignedInt(let num):
            if num > UInt64(Int.max) {
                throw CBORCodingError.decodingError("Value out of range")
            }
            return Int(num)
        case .negativeInt(let num):
            if num < Int64(Int.min) {
                throw CBORCodingError.decodingError("Value out of range")
            }
            return Int(num)
        default:
            throw CBORCodingError.decodingError("Expected integer")
        }
    }
    
    func decode(_ type: Int8.Type) throws -> Int8 {
        let intVal = try decode(Int.self)
        if intVal < Int(Int8.min) || intVal > Int(Int8.max) {
            throw CBORCodingError.decodingError("Value out of range for Int8")
        }
        return Int8(intVal)
    }
    
    func decode(_ type: Int16.Type) throws -> Int16 {
        let intVal = try decode(Int.self)
        if intVal < Int(Int16.min) || intVal > Int(Int16.max) {
            throw CBORCodingError.decodingError("Value out of range for Int16")
        }
        return Int16(intVal)
    }
    
    func decode(_ type: Int32.Type) throws -> Int32 {
        let intVal = try decode(Int.self)
        if intVal < Int(Int32.min) || intVal > Int(Int32.max) {
            throw CBORCodingError.decodingError("Value out of range for Int32")
        }
        return Int32(intVal)
    }
    
    func decode(_ type: Int64.Type) throws -> Int64 {
        switch value {
        case .unsignedInt(let num):
            if num > UInt64(Int64.max) {
                throw CBORCodingError.decodingError("Value out of range for Int64")
            }
            return Int64(num)
        case .negativeInt(let num):
            return num
        default:
            throw CBORCodingError.decodingError("Expected integer")
        }
    }
    
    func decode(_ type: UInt.Type) throws -> UInt {
        switch value {
        case .unsignedInt(let num):
            return UInt(num)
        default:
            throw CBORCodingError.decodingError("Expected unsigned integer")
        }
    }
    
    func decode(_ type: UInt8.Type) throws -> UInt8 {
        let uintVal = try decode(UInt.self)
        if uintVal > UInt(UInt8.max) {
            throw CBORCodingError.decodingError("Value out of range for UInt8")
        }
        return UInt8(uintVal)
    }
    
    func decode(_ type: UInt16.Type) throws -> UInt16 {
        let uintVal = try decode(UInt.self)
        if uintVal > UInt(UInt16.max) {
            throw CBORCodingError.decodingError("Value out of range for UInt16")
        }
        return UInt16(uintVal)
    }
    
    func decode(_ type: UInt32.Type) throws -> UInt32 {
        let uintVal = try decode(UInt.self)
        if uintVal > UInt(UInt32.max) {
            throw CBORCodingError.decodingError("Value out of range for UInt32")
        }
        return UInt32(uintVal)
    }
    
    func decode(_ type: UInt64.Type) throws -> UInt64 {
        switch value {
        case .unsignedInt(let num):
            return num
        default:
            throw CBORCodingError.decodingError("Expected unsigned integer")
        }
    }
    
    func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
        let nestedDecoder = _CBORDecoder(cborValue: value)
        return try T(from: nestedDecoder)
    }
}

// MARK: - UnkeyedDecodingContainer

fileprivate struct CBORUnkeyedDecodingContainer: UnkeyedDecodingContainer {
    var codingPath: [CodingKey] { decoder.codingPath }
    let decoder: _CBORDecoder
    
    let array: [CBOR]
    var currentIndex: Int = 0
    
    var count: Int? { array.count }
    var isAtEnd: Bool {
        currentIndex >= array.count
    }
    
    init(decoder: _CBORDecoder, array: [CBOR]) {
        self.decoder = decoder
        self.array = array
        self.currentIndex = 0
    }
    
    mutating func decodeNil() throws -> Bool {
        guard !isAtEnd else { throw CBORCodingError.decodingError("Out of range") }
        if case .null = array[currentIndex] {
            currentIndex += 1
            return true
        }
        return false
    }
    
    mutating func decode<T>(_ type: T.Type) throws -> T where T : Decodable {
        guard !isAtEnd else {
            throw CBORCodingError.decodingError("Array index out of bounds")
        }
        let val = array[currentIndex]
        currentIndex += 1
        let nestedDecoder = _CBORDecoder(cborValue: val)
        return try T(from: nestedDecoder)
    }
    
    mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type)
        throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey
    {
        guard !isAtEnd else {
            throw CBORCodingError.decodingError("Array index out of bounds")
        }
        let val = array[currentIndex]
        currentIndex += 1
        let nestedDecoder = _CBORDecoder(cborValue: val)
        return try nestedDecoder.container(keyedBy: keyType)
    }
    
    mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        guard !isAtEnd else {
            throw CBORCodingError.decodingError("Array index out of bounds")
        }
        let val = array[currentIndex]
        currentIndex += 1
        let nestedDecoder = _CBORDecoder(cborValue: val)
        return try nestedDecoder.unkeyedContainer()
    }
    
    mutating func superDecoder() throws -> Decoder {
        return decoder
    }
}

// MARK: - KeyedDecodingContainer

fileprivate struct CBORKeyedDecodingContainer<K: CodingKey>: KeyedDecodingContainerProtocol {
    typealias Key = K
    
    var codingPath: [CodingKey] { decoder.codingPath }
    let decoder: _CBORDecoder
    
    let dictionary: [CBOR : CBOR]
    
    init(decoder: _CBORDecoder, dictionary: [CBOR: CBOR]) {
        self.decoder = decoder
        self.dictionary = dictionary
    }
    
    var allKeys: [K] {
        dictionary.keys.compactMap { key -> K? in
            if case let .utf8String(str) = key {
                return K(stringValue: str)
            }
            return nil
        }
    }
    
    func contains(_ key: K) -> Bool {
        let cborKey = CBOR.utf8String(key.stringValue)
        return dictionary[cborKey] != nil
    }
    
    func decodeNil(forKey key: K) throws -> Bool {
        guard let val = dictionary[.utf8String(key.stringValue)] else {
            return true
        }
        if case .null = val {
            return true
        }
        return false
    }
    
    func decode(_ type: Bool.Type, forKey key: K) throws -> Bool {
        let container = try singleValueContainer(forKey: key)
        return try container.decode(Bool.self)
    }
    
    func decode(_ type: String.Type, forKey key: K) throws -> String {
        let container = try singleValueContainer(forKey: key)
        return try container.decode(String.self)
    }
    
    func decode(_ type: Double.Type, forKey key: K) throws -> Double {
        let container = try singleValueContainer(forKey: key)
        return try container.decode(Double.self)
    }
    
    func decode(_ type: Float.Type, forKey key: K) throws -> Float {
        let container = try singleValueContainer(forKey: key)
        return try container.decode(Float.self)
    }
    
    func decode(_ type: Int.Type, forKey key: K) throws -> Int {
        let container = try singleValueContainer(forKey: key)
        return try container.decode(Int.self)
    }
    
    func decode(_ type: Int8.Type, forKey key: K) throws -> Int8 {
        let container = try singleValueContainer(forKey: key)
        return try container.decode(Int8.self)
    }
    
    func decode(_ type: Int16.Type, forKey key: K) throws -> Int16 {
        let container = try singleValueContainer(forKey: key)
        return try container.decode(Int16.self)
    }
    
    func decode(_ type: Int32.Type, forKey key: K) throws -> Int32 {
        let container = try singleValueContainer(forKey: key)
        return try container.decode(Int32.self)
    }
    
    func decode(_ type: Int64.Type, forKey key: K) throws -> Int64 {
        let container = try singleValueContainer(forKey: key)
        return try container.decode(Int64.self)
    }
    
    func decode(_ type: UInt.Type, forKey key: K) throws -> UInt {
        let container = try singleValueContainer(forKey: key)
        return try container.decode(UInt.self)
    }
    
    func decode(_ type: UInt8.Type, forKey key: K) throws -> UInt8 {
        let container = try singleValueContainer(forKey: key)
        return try container.decode(UInt8.self)
    }
    
    func decode(_ type: UInt16.Type, forKey key: K) throws -> UInt16 {
        let container = try singleValueContainer(forKey: key)
        return try container.decode(UInt16.self)
    }
    
    func decode(_ type: UInt32.Type, forKey key: K) throws -> UInt32 {
        let container = try singleValueContainer(forKey: key)
        return try container.decode(UInt32.self)
    }
    
    func decode(_ type: UInt64.Type, forKey key: K) throws -> UInt64 {
        let container = try singleValueContainer(forKey: key)
        return try container.decode(UInt64.self)
    }
    
    func decode<T>(_ type: T.Type, forKey key: K) throws -> T where T : Decodable {
        let container = try singleValueContainer(forKey: key)
        return try container.decode(T.self)
    }
    
    func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type,
                                    forKey key: K) throws -> KeyedDecodingContainer<NestedKey> {
        fatalError("Keyed nestedContainer not implemented")
    }
    
    func nestedUnkeyedContainer(forKey key: K) throws -> UnkeyedDecodingContainer {
        fatalError("Keyed nestedUnkeyedContainer not implemented")
    }
    
    func superDecoder() throws -> Decoder {
        return decoder
    }
    
    func superDecoder(forKey key: K) throws -> Decoder {
        return decoder
    }
    
    private func singleValueContainer(forKey key: K) throws -> CBORSingleValueDecodingContainer {
        let cborKey = CBOR.utf8String(key.stringValue)
        guard let val = dictionary[cborKey] else {
            throw CBORCodingError.decodingError("Key not found: \(key.stringValue) (available keys: \(dictionary.keys))")
        }
        return CBORSingleValueDecodingContainer(decoder: decoder, value: val)
    }
}
