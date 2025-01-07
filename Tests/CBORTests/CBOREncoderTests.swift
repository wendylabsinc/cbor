import Testing
import Foundation

@testable import CBOR

@Suite("CBOR Encoding Tests")
struct CBOREncoderTests {

    @Test func testNumberEncoding() throws {
        let encoder = CBOREncoder()
        let decoder = CBORDecoder()

        let encoded = try encoder.encode(123)
        let decoded = try decoder.decode(Int.self, from: encoded)

        #expect(decoded == 123)

        // Test UInt8
        let uint8Value: UInt8 = 255
        let encodedUInt8 = try encoder.encode(uint8Value)
        let decodedUInt8 = try decoder.decode(UInt8.self, from: encodedUInt8)
        #expect(decodedUInt8 == uint8Value)

        // Test Int8
        let int8Value: Int8 = -128
        let encodedInt8 = try encoder.encode(int8Value)
        let decodedInt8 = try decoder.decode(Int8.self, from: encodedInt8)
        #expect(decodedInt8 == int8Value)

        // Test UInt16
        let uint16Value: UInt16 = 65535
        let encodedUInt16 = try encoder.encode(uint16Value)
        let decodedUInt16 = try decoder.decode(UInt16.self, from: encodedUInt16)
        #expect(decodedUInt16 == uint16Value)

        // Test Int16
        let int16Value: Int16 = -32768
        let encodedInt16 = try encoder.encode(int16Value)
        let decodedInt16 = try decoder.decode(Int16.self, from: encodedInt16)
        #expect(decodedInt16 == int16Value)

        // Test UInt32
        let uint32Value: UInt32 = 4294967295
        let encodedUInt32 = try encoder.encode(uint32Value)
        let decodedUInt32 = try decoder.decode(UInt32.self, from: encodedUInt32)
        #expect(decodedUInt32 == uint32Value)

        // Test Int32
        let int32Value: Int32 = -2147483648
        let encodedInt32 = try encoder.encode(int32Value)
        let decodedInt32 = try decoder.decode(Int32.self, from: encodedInt32)
        #expect(decodedInt32 == int32Value)

        // Test UInt64
        let uint64Value: UInt64 = 18446744073709551615
        let encodedUInt64 = try encoder.encode(uint64Value)
        let decodedUInt64 = try decoder.decode(UInt64.self, from: encodedUInt64)
        #expect(decodedUInt64 == uint64Value)

        // Test Int64
        let int64Value: Int64 = -9223372036854775808
        let encodedInt64 = try encoder.encode(int64Value)
        let decodedInt64 = try decoder.decode(Int64.self, from: encodedInt64)
        #expect(decodedInt64 == int64Value)
    }

    @Test func testStringEncoding() throws {
        let encoder = CBOREncoder()
        let decoder = CBORDecoder()

        let encoded = try encoder.encode("Hello, World!")
        let decoded = try decoder.decode(String.self, from: encoded)

        #expect(decoded == "Hello, World!")
    }

    struct User: Equatable, Codable {
        let name: String
        let age: Int
        let isActive: Bool
        let score: Double
    }

    @Test func testSimpleRoundTrip() throws {
        let user = User(name: "Alice", age: 30, isActive: true, score: 42.5)

        let encoder = CBOREncoder()
        let decoder = CBORDecoder()

        let encoded = try encoder.encode(user)
        let decoded = try decoder.decode(User.self, from: encoded)

        #expect(user == decoded)
    }

    struct UserWithOptional: Equatable, Codable {
        let name: String
        let age: Int
        let isActive: Bool?
        let score: Double?
    }

    @Test func testOptionalRoundTrip() throws {
        let user = UserWithOptional(name: "Alice", age: 30, isActive: nil, score: 42.5)

        let encoder = CBOREncoder()
        let decoder = CBORDecoder()

        let encoded = try encoder.encode(user)
        let decoded = try decoder.decode(UserWithOptional.self, from: encoded)

        #expect(user == decoded)
    }

    struct UserWithArray: Equatable, Codable {
        struct Friend: Equatable, Codable {
            let name: String
            let age: Int
        }

        let name: String
        let age: Int
        let isActive: Bool
        let score: Double
        let friends: [Friend]
    }

    @Test func testArrayRoundTrip() throws {
        let user = UserWithArray(
            name: "Alice", age: 30, isActive: true, score: 42.5,
            friends: [
                UserWithArray.Friend(name: "Bob", age: 25),
                UserWithArray.Friend(name: "Charlie", age: 35),
            ])

        let encoder = CBOREncoder()
        let decoder = CBORDecoder()

        let encoded = try encoder.encode(user)
        let decoded = try decoder.decode(UserWithArray.self, from: encoded)

        #expect(user == decoded)
    }

    struct UserWithNestedMap: Equatable, Codable {
        let name: String
        let age: Int
        let isActive: Bool
        let score: Double
        let friends: [String: Int]
    }

    @Test func testMapRoundTrip() throws {
        let user = UserWithNestedMap(
            name: "Alice", age: 30, isActive: true, score: 42.5,
            friends: ["Bob": 25, "Charlie": 35])

        let encoder = CBOREncoder()
        let decoder = CBORDecoder()

        let encoded = try encoder.encode(user)
        let decoded = try decoder.decode(UserWithNestedMap.self, from: encoded)

        #expect(user == decoded)
    }

    @Test func testNumericBoundaries() throws {
        struct Numbers: Codable, Equatable {
            let int8: Int8
            let int16: Int16
            let int32: Int32
            let int64: Int64
            let uint8: UInt8
            let uint16: UInt16
            let uint32: UInt32
            let uint64: UInt64

            // Add CodingKeys to ensure consistent key order
            private enum CodingKeys: String, CodingKey {
                case int8, int16, int32, int64
                case uint8, uint16, uint32, uint64
            }
        }

        let numbers = Numbers(
            int8: Int8.max,
            int16: Int16.max,
            int32: Int32.max,
            int64: Int64.max,
            uint8: UInt8.max,
            uint16: UInt16.max,
            uint32: UInt32.max,
            uint64: UInt64.max
        )

        let encoder = CBOREncoder()
        let decoder = CBORDecoder()

        let encoded = try encoder.encode(numbers)
        let decoded = try decoder.decode(Numbers.self, from: encoded)

        #expect(decoded == numbers)

        // Test minimum values
        let minNumbers = Numbers(
            int8: Int8.min,
            int16: Int16.min,
            int32: Int32.min,
            int64: Int64.min,
            uint8: UInt8.min,
            uint16: UInt16.min,
            uint32: UInt32.min,
            uint64: UInt64.min
        )

        let encodedMin = try encoder.encode(minNumbers)
        let decodedMin = try decoder.decode(Numbers.self, from: encodedMin)

        #expect(decodedMin == minNumbers)
    }

    @Test func testByteStrings() throws {
        struct ByteData: Codable, Equatable {
            let data: Data
        }

        let testData = Data([0x01, 0x02, 0x03, 0xFF])
        let byteData = ByteData(data: testData)

        let encoder = CBOREncoder()
        let decoder = CBORDecoder()

        let encoded = try encoder.encode(byteData)
        let decoded = try decoder.decode(ByteData.self, from: encoded)

        #expect(decoded == byteData)

        // Test empty Data
        let emptyData = ByteData(data: Data())
        let encodedEmpty = try encoder.encode(emptyData)
        let decodedEmpty = try decoder.decode(ByteData.self, from: encodedEmpty)

        #expect(decodedEmpty == emptyData)
    }

    @Test func testEmptyCollections() throws {
        struct EmptyCollections: Codable, Equatable {
            let emptyArray: [Int]
            let emptyMap: [String: Int]
            let emptyString: String
            let emptyData: Data

            // Add CodingKeys to ensure consistent key order
            private enum CodingKeys: String, CodingKey {
                case emptyArray, emptyMap, emptyString, emptyData
            }
        }

        let empty = EmptyCollections(
            emptyArray: [],
            emptyMap: [:],
            emptyString: "",
            emptyData: Data()
        )

        let encoder = CBOREncoder()
        let decoder = CBORDecoder()

        let encoded = try encoder.encode(empty)
        let decoded = try decoder.decode(EmptyCollections.self, from: encoded)

        #expect(decoded == empty)
    }

    @Test func testDeepNesting() throws {
        struct NestedStructure: Codable, Equatable {
            let arrays: [[[[Int]]]]
            let maps: [String: [String: [String: Int]]]
        }

        let nested = NestedStructure(
            arrays: [[[[1, 2], [3, 4]], [[5, 6], [7, 8]]]],
            maps: ["a": ["b": ["c": 1, "d": 2], "e": ["f": 3]]]
        )

        let encoder = CBOREncoder()
        let decoder = CBORDecoder()

        let encoded = try encoder.encode(nested)
        let decoded = try decoder.decode(NestedStructure.self, from: encoded)

        #expect(decoded == nested)
    }

    @Test func testErrorCases() throws {
        let encoder = CBOREncoder()
        let decoder = CBORDecoder()

        // Test decoding invalid data
        let invalidData = Data([0xFF, 0xFF, 0xFF])
        var didThrow = false
        do {
            _ = try decoder.decode(User.self, from: invalidData)
        } catch {
            didThrow = true
            #expect(error is CBORCodingError)
        }
        #expect(didThrow, "Should have thrown an error for invalid data")

        // Test decoding wrong type
        let user = User(name: "Alice", age: 30, isActive: true, score: 42.5)
        let encoded = try encoder.encode(user)
        
        didThrow = false
        do {
            _ = try decoder.decode(UserWithArray.self, from: encoded)
        } catch {
            didThrow = true
            #expect(error is CBORCodingError)
        }
        #expect(didThrow, "Should have thrown an error for type mismatch")

        // Test decoding truncated data
        let truncated = encoded.prefix(encoded.count - 1)
        didThrow = false
        do {
            _ = try decoder.decode(User.self, from: truncated)
        } catch {
            didThrow = true
            #expect(error is CBORCodingError)
        }
        #expect(didThrow, "Should have thrown an error for truncated data")
    }
}
