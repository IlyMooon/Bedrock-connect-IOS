import XCTest
@testable import BedrockConnectCore

final class VarIntTests: XCTestCase {
    func testVarUInt32() throws {
        let cases: [UInt32] = [0, 1, 127, 128, 255, 300, 16384, 2097151, 4294967295]
        for num in cases {
            let encoded = VarInt.encodeVarUInt32(num)
            var offset = 0
            let val = try VarInt.decodeVarUInt32(encoded, offset: &offset)
            XCTAssertEqual(val, num)
            XCTAssertEqual(offset, encoded.count)
        }
    }

    func testVarInt32() throws {
        let cases: [Int32] = [0, -1, 1, -128, 127, -2147483648, 2147483647]
        for num in cases {
            let encoded = VarInt.encodeVarInt32(num)
            var offset = 0
            let val = try VarInt.decodeVarInt32(encoded, offset: &offset)
            XCTAssertEqual(val, num)
            XCTAssertEqual(offset, encoded.count)
        }
    }

    func testVarUInt64() throws {
        let cases: [UInt64] = [0, 1, 127, 128, 255, 100000000000]
        for num in cases {
            let encoded = VarInt.encodeVarUInt64(num)
            var offset = 0
            let val = try VarInt.decodeVarUInt64(encoded, offset: &offset)
            XCTAssertEqual(val, num)
            XCTAssertEqual(offset, encoded.count)
        }
    }

    func testString() throws {
        let testStr = "Hello Bedrock Connect! 🎮 §aMinecraft"
        let encoded = VarInt.encodeString(testStr)
        var offset = 0
        let decoded = try VarInt.decodeString(encoded, offset: &offset)
        XCTAssertEqual(decoded, testStr)
        XCTAssertEqual(offset, encoded.count)
    }
}
