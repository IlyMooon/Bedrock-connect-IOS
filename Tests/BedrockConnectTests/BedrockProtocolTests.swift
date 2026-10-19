import XCTest
@testable import BedrockConnectCore

final class BedrockProtocolTests: XCTestCase {
    func testPacketHeader() throws {
        let header = BedrockProtocol.encodePacketHeader(packetId: BedrockProtocol.idTransfer)
        var offset = 0
        let pid = try BedrockProtocol.decodePacketHeader(data: header, offset: &offset)
        XCTAssertEqual(pid, BedrockProtocol.idTransfer)
    }

    func testTransferPacket() throws {
        let targetIp = "play.mycustomserver.net"
        let targetPort: UInt16 = 19132
        let pk = BedrockProtocol.buildTransferPacket(address: targetIp, port: targetPort)
        var offset = 0
        let pid = try BedrockProtocol.decodePacketHeader(data: pk, offset: &offset)
        XCTAssertEqual(pid, BedrockProtocol.idTransfer)
        let decodedIp = try VarInt.decodeString(pk, offset: &offset)
        XCTAssertEqual(decodedIp, targetIp)
    }

    func testBatchZlib() {
        let pk1 = BedrockProtocol.buildPlayStatus(status: 0)
        let pk2 = BedrockProtocol.buildTransferPacket(address: "192.168.1.100", port: 19132)
        let batch = BedrockProtocol.encodeBatch(packets: [pk1, pk2], compressionAlgo: Int(BedrockProtocol.compressionZlib))

        XCTAssertEqual(batch[0], 0xFE)
        XCTAssertEqual(batch[1], 0x00) // Flate / Zlib marker

        let decoded = BedrockProtocol.decodeBatch(batch)
        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded[0], pk1)
        XCTAssertEqual(decoded[1], pk2)
    }

    func testResourcePacksPackets() throws {
        let motionPk = BedrockProtocol.buildSetEntityMotion(runtimeEntityId: 1)
        var offset = 0
        let pidMotion = try BedrockProtocol.decodePacketHeader(data: motionPk, offset: &offset)
        XCTAssertEqual(pidMotion, BedrockProtocol.idSetEntityMotion)
        XCTAssertEqual(motionPk.count, 15) // 1 byte header + 14 bytes payload

        let infoPk = BedrockProtocol.buildResourcePacksInfo(protocolVersion: 2169)
        offset = 0
        let pid1 = try BedrockProtocol.decodePacketHeader(data: infoPk, offset: &offset)
        XCTAssertEqual(pid1, BedrockProtocol.idResourcePacksInfo)
        XCTAssertEqual(infoPk.count, 24) // 1 byte header + 23 bytes payload

        let stackPk = BedrockProtocol.buildResourcePackStack(gameVersion: "*", protocolVersion: 2169)
        offset = 0
        let pid2 = try BedrockProtocol.decodePacketHeader(data: stackPk, offset: &offset)
        XCTAssertEqual(pid2, BedrockProtocol.idResourcePackStack)
        XCTAssertEqual(stackPk.count, 11) // 1 byte header + 10 bytes payload

        var dummyHavePacks = BedrockProtocol.encodePacketHeader(packetId: BedrockProtocol.idResourcePackClientResponse)
        dummyHavePacks.append(VarInt.encodeVarUInt32(UInt32(BedrockProtocol.responseStatusHaveAllPacks - 1)))
        dummyHavePacks.append(VarInt.encodeString("downloadingfinished"))
        let status1 = BedrockProtocol.parseResourcePackClientResponse(dummyHavePacks, protocolVersion: 2169)
        XCTAssertEqual(status1, BedrockProtocol.responseStatusHaveAllPacks)

        var dummyCompleted = BedrockProtocol.encodePacketHeader(packetId: BedrockProtocol.idResourcePackClientResponse)
        dummyCompleted.append(VarInt.encodeVarUInt32(UInt32(BedrockProtocol.responseStatusCompleted - 1)))
        dummyCompleted.append(VarInt.encodeString("resourcepackstackfinished"))
        let status2 = BedrockProtocol.parseResourcePackClientResponse(dummyCompleted, protocolVersion: 2169)
        XCTAssertEqual(status2, BedrockProtocol.responseStatusCompleted)
    }

    func testStartGameAndWorldPackets() throws {
        let sgPk = BedrockProtocol.buildStartGame(protocolVersion: 2169)
        var offset = 0
        let pid1 = try BedrockProtocol.decodePacketHeader(data: sgPk, offset: &offset)
        XCTAssertEqual(pid1, BedrockProtocol.idStartGame)
        XCTAssertEqual(sgPk.count, 226) // 1 byte header + 225 bytes verified StartGame payload
        XCTAssertNotNil(sgPk.range(of: Data("world".utf8)))

        let chunkPk = BedrockProtocol.buildLevelChunk()
        offset = 0
        let pid2 = try BedrockProtocol.decodePacketHeader(data: chunkPk, offset: &offset)
        XCTAssertEqual(pid2, BedrockProtocol.idLevelChunk)
        XCTAssertEqual(chunkPk.count, 271) // 1 byte header + 2 bytes coords + 268 bytes valid chunk payload

        let chunkNeg = BedrockProtocol.buildLevelChunk(chunkX: -1, chunkZ: -1)
        XCTAssertEqual(chunkNeg.count, 271)

        let attrPk = BedrockProtocol.buildUpdateAttributes()
        offset = 0
        let pidAttr = try BedrockProtocol.decodePacketHeader(data: attrPk, offset: &offset)
        XCTAssertEqual(pidAttr, BedrockProtocol.idUpdateAttributes)
        XCTAssertEqual(attrPk.count, 48) // 1 byte header + 47 bytes attribute data

        let spawnPk = BedrockProtocol.buildPlayerSpawn()
        offset = 0
        let pid3 = try BedrockProtocol.decodePacketHeader(data: spawnPk, offset: &offset)
        XCTAssertEqual(pid3, BedrockProtocol.idPlayStatus)
        let statusVal = spawnPk.subdata(in: 1..<5).withUnsafeBytes { $0.load(as: Int32.self).bigEndian }
        XCTAssertEqual(statusVal, BedrockProtocol.statusPlayerSpawn)

        let itemCompPk = BedrockProtocol.buildItemComponent()
        offset = 0
        let pid4 = try BedrockProtocol.decodePacketHeader(data: itemCompPk, offset: &offset)
        XCTAssertEqual(pid4, BedrockProtocol.idItemComponent)

        let creativePk = BedrockProtocol.buildCreativeContent()
        offset = 0
        let pid5 = try BedrockProtocol.decodePacketHeader(data: creativePk, offset: &offset)
        XCTAssertEqual(pid5, BedrockProtocol.idCreativeContent)

        let radiusPk = BedrockProtocol.buildChunkRadiusUpdated(radius: 8)
        offset = 0
        let pid6 = try BedrockProtocol.decodePacketHeader(data: radiusPk, offset: &offset)
        XCTAssertEqual(pid6, BedrockProtocol.idChunkRadiusUpdated)
    }
}
