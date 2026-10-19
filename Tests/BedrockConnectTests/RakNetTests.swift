import XCTest
@testable import BedrockConnectCore

final class RakNetTests: XCTestCase {
    func testUInt24LE() throws {
        let cases: [UInt32] = [0, 1, 255, 65535, 16777215]
        for num in cases {
            let enc = RakNet.encodeUInt24LE(num)
            XCTAssertEqual(enc.count, 3)
            var offset = 0
            let dec = try RakNet.decodeUInt24LE(enc, offset: &offset)
            XCTAssertEqual(dec, num)
            XCTAssertEqual(offset, 3)
        }
    }

    func testAddress() throws {
        let ip = "192.168.1.50"
        let port: UInt16 = 19132
        let enc = RakNet.encodeAddress(ip: ip, port: port)
        var offset = 0
        let (decIp, decPort) = try RakNet.decodeAddress(enc, offset: &offset)
        XCTAssertEqual(decIp, ip)
        XCTAssertEqual(decPort, port)
        XCTAssertEqual(offset, enc.count)
    }

    func testUnconnectedPong() {
        let pong = RakNet.buildUnconnectedPong(pingTime: 123456, serverGuid: 99999999, motd: "MCPE;Test Server;748;1.21.50;1;100;99999999;Sub;Survival")
        let parsed = RakNet.parseUnconnectedPong(pong)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.pingTime, 123456)
        XCTAssertEqual(parsed?.serverGuid, 99999999)
        XCTAssertTrue(parsed?.motd.contains("Test Server") == true)
    }

    func testDatagramAndFrame() {
        let payload = Data("Hello Bedrock Frame".utf8)
        let frame = EncapsulatedPacket(
            content: payload,
            reliability: RakNet.reliabilityReliableOrdered,
            messageIndex: 42,
            orderIndex: 1,
            orderChannel: 0
        )
        let datagram = RakNet.buildDatagram(sequenceNumber: 10, frames: [frame])
        let parsed = RakNet.parseDatagram(datagram)
        XCTAssertNotNil(parsed)
        guard let (seq, frames) = parsed else { return }
        XCTAssertEqual(seq, 10)
        XCTAssertEqual(frames.count, 1)
        XCTAssertEqual(frames[0].content, payload)
        XCTAssertEqual(frames[0].messageIndex, 42)
        XCTAssertEqual(frames[0].orderIndex, 1)
    }

    func testAck() {
        let seqs: [UInt32] = [1, 2, 3, 5, 8, 9, 10]
        let ackPkt = RakNet.buildAck(sequenceNumbers: seqs)
        let parsed = RakNet.parseAck(ackPkt)
        XCTAssertEqual(parsed.sorted(), seqs.sorted())
    }

    func testSplitFrame() throws {
        let content = Data(repeating: 0x58, count: 1500)
        let frame = EncapsulatedPacket(
            content: content,
            reliability: RakNet.reliabilityReliableOrdered,
            messageIndex: 1,
            orderIndex: 0,
            split: true,
            splitCount: 2,
            splitId: 101,
            splitIndex: 0
        )
        let serialized = frame.serialize()
        var offset = 0
        let deserialized = try EncapsulatedPacket.deserialize(data: serialized, offset: &offset)
        XCTAssertTrue(deserialized.split)
        XCTAssertEqual(deserialized.splitCount, 2)
        XCTAssertEqual(deserialized.splitId, 101)
        XCTAssertEqual(deserialized.splitIndex, 0)
        XCTAssertEqual(deserialized.content, content)
    }
}
