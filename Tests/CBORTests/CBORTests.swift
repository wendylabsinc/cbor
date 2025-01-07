import Testing
import Foundation

@testable import CBOR

@Suite("CBOR Type Tests")
struct CBORTests {
    
    @Test func testCBOREquality() throws {
        // Test simple values
        #expect(CBOR.null == CBOR.null)
        #expect(CBOR.boolean(true) == CBOR.boolean(true))
        #expect(CBOR.boolean(false) == CBOR.boolean(false))
        #expect(CBOR.boolean(true) != CBOR.boolean(false))
        
        // Test numbers
        #expect(CBOR.unsignedInt(42) == CBOR.unsignedInt(42))
        #expect(CBOR.negativeInt(42) == CBOR.negativeInt(42))
        #expect(CBOR.float(Float32(3.14)) == CBOR.float(Float32(3.14)))
        #expect(CBOR.double(3.14159) == CBOR.double(3.14159))
        #expect(CBOR.half(Float32(3.14)) == CBOR.half(Float32(3.14)))
        
        // Test strings
        #expect(CBOR.utf8String("hello") == CBOR.utf8String("hello"))
        #expect(CBOR.utf8String("hello") != CBOR.utf8String("world"))
        
        // Test byte strings
        let bytes1: [UInt8] = [0x01, 0x02, 0x03]
        let bytes2: [UInt8] = [0x01, 0x02, 0x03]
        #expect(CBOR.byteString(bytes1) == CBOR.byteString(bytes2))
        
        // Test arrays
        #expect(CBOR.array([.null, .boolean(true)]) == CBOR.array([.null, .boolean(true)]))
        #expect(CBOR.array([.null]) != CBOR.array([.boolean(true)]))
        
        // Test maps
        let map1: [CBOR: CBOR] = [.utf8String("key"): .utf8String("value")]
        let map2: [CBOR: CBOR] = [.utf8String("key"): .utf8String("value")]
        #expect(CBOR.map(map1) == CBOR.map(map2))
    }
    
    @Test func testCBORHashable() throws {
        // Test simple values in Set
        var set = Set<CBOR>()
        set.insert(.null)
        set.insert(.boolean(true))
        set.insert(.boolean(false))
        
        #expect(set.contains(.null))
        #expect(set.contains(.boolean(true)))
        #expect(set.contains(.boolean(false)))
        #expect(!set.contains(.utf8String("not in set")))
        
        // Test numbers in Set
        set.insert(.unsignedInt(42))
        set.insert(.negativeInt(42))
        set.insert(.float(Float32(3.14)))
        
        #expect(set.contains(.unsignedInt(42)))
        #expect(set.contains(.negativeInt(42)))
        #expect(set.contains(.float(Float32(3.14))))
        
        // Test strings in Set
        set.insert(.utf8String("hello"))
        #expect(set.contains(.utf8String("hello")))
        #expect(!set.contains(.utf8String("world")))
        
        // Test byte strings in Set
        let bytes: [UInt8] = [0x01, 0x02, 0x03]
        set.insert(.byteString(bytes))
        #expect(set.contains(.byteString(bytes)))
        
        // Test arrays in Set
        let array: [CBOR] = [.null, .boolean(true)]
        set.insert(.array(array))
        #expect(set.contains(.array(array)))
        
        // Test maps in Set
        let map: [CBOR: CBOR] = [.utf8String("key"): .utf8String("value")]
        set.insert(.map(map))
        #expect(set.contains(.map(map)))
    }
    
    @Test func testCBORTags() throws {
        // Test standard date/time string tag
        let dateString = "2023-01-01T00:00:00Z"
        let taggedDate = CBOR.tagged(CBOR.Tag.standardDateTimeString, .utf8String(dateString))
        
        // Test epoch-based date/time tag
        let timestamp = 1672531200.0 // 2023-01-01 00:00:00 UTC
        let taggedTimestamp = CBOR.tagged(CBOR.Tag.epochBasedDateTime, .double(timestamp))
        
        // Test positive bignum tag
        let bignumBytes: [UInt8] = [0xFF, 0xFF, 0xFF, 0xFF]
        let taggedBignum = CBOR.tagged(CBOR.Tag.positiveBignum, .byteString(bignumBytes))
        
        // Test negative bignum tag
        let negBignumBytes: [UInt8] = [0xFF, 0xFF, 0xFF, 0xFF]
        let taggedNegBignum = CBOR.tagged(CBOR.Tag.negativeBignum, .byteString(negBignumBytes))
        
        // Test decimal fraction tag
        let decimalArray: [CBOR] = [.negativeInt(2), .unsignedInt(314)]
        let taggedDecimal = CBOR.tagged(CBOR.Tag.decimalFraction, .array(decimalArray))
        
        // Test bigfloat tag
        let bigfloatArray: [CBOR] = [.negativeInt(2), .unsignedInt(314)]
        let taggedBigfloat = CBOR.tagged(CBOR.Tag.bigfloat, .array(bigfloatArray))
        
        // Test base64url tag
        let base64String = "aGVsbG8="
        let taggedBase64url = CBOR.tagged(CBOR.Tag.base64Url, .utf8String(base64String))
        
        // Test base64 tag
        let taggedBase64 = CBOR.tagged(CBOR.Tag.base64, .utf8String(base64String))
        
        // Test URI tag
        let uriString = "https://example.com"
        let taggedURI = CBOR.tagged(CBOR.Tag.uri, .utf8String(uriString))
        
        // Test that all tagged values are not equal
        #expect(taggedDate != taggedTimestamp)
        #expect(taggedBignum != taggedNegBignum)
        #expect(taggedDecimal != taggedBigfloat)
        #expect(taggedBase64url != taggedBase64)
    }
    
    @Test func testCBORTagRawValues() throws {
        // Test standard tag raw values
        #expect(CBOR.Tag.standardDateTimeString.rawValue == 0)
        #expect(CBOR.Tag.epochBasedDateTime.rawValue == 1)
        #expect(CBOR.Tag.positiveBignum.rawValue == 2)
        #expect(CBOR.Tag.negativeBignum.rawValue == 3)
        #expect(CBOR.Tag.decimalFraction.rawValue == 4)
        #expect(CBOR.Tag.bigfloat.rawValue == 5)
        #expect(CBOR.Tag.base64Url.rawValue == 33)
        #expect(CBOR.Tag.base64.rawValue == 34)
        #expect(CBOR.Tag.uri.rawValue == 32)
        
        // Test custom tag creation
        let customTag = CBOR.Tag(rawValue: 100)
        #expect(customTag.rawValue == 100)
    }
}
