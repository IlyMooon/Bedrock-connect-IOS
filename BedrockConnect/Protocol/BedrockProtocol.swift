import Foundation
import zlib

public struct BedrockProtocol {
    public static let idLogin: UInt32 = 1
    public static let idPlayStatus: UInt32 = 2
    public static let idServerToClientHandshake: UInt32 = 3
    public static let idClientToServerHandshake: UInt32 = 4
    public static let idDisconnect: UInt32 = 5
    public static let idResourcePacksInfo: UInt32 = 6
    public static let idResourcePackStack: UInt32 = 7
    public static let idResourcePackClientResponse: UInt32 = 8
    public static let idStartGame: UInt32 = 11
    public static let idUpdateAttributes: UInt32 = 29
    public static let idLevelChunk: UInt32 = 58
    public static let idRequestChunkRadius: UInt32 = 69
    public static let idChunkRadiusUpdated: UInt32 = 70
    public static let idTransfer: UInt32 = 85
    public static let idSetLocalPlayerAsInitialized: UInt32 = 113
    public static let idSetEntityMotion: UInt32 = 40
    public static let idNetworkSettings: UInt32 = 143
    public static let idCreativeContent: UInt32 = 145
    public static let idItemComponent: UInt32 = 162
    public static let idRequestNetworkSettings: UInt32 = 193

    public static let responseStatusRefused: Int = 1
    public static let responseStatusSendPacks: Int = 2
    public static let responseStatusHaveAllPacks: Int = 3
    public static let responseStatusCompleted: Int = 4

    public static let currentProtocolVersion: Int = 2169
    public static let currentVersionString: String = "1.26.45"

    public static let compressionZlib: UInt16 = 0
    public static let compressionSnappy: UInt16 = 1
    public static let compressionNone: UInt16 = 0xFFFF

    public static let statusLoginSuccess: Int32 = 0
    public static let statusPlayerSpawn: Int32 = 3

    // MARK: - Deflate / Zlib Compression
    public static func compressFlate(_ data: Data) -> Data {
        guard !data.isEmpty else { return Data() }

        var stream = z_stream()
        // -MAX_WBITS enables raw deflate (RFC 1951)
        guard deflateInit2_(&stream, Z_DEFAULT_COMPRESSION, Z_DEFLATED, -MAX_WBITS, 8, Z_DEFAULT_STRATEGY, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else {
            return data
        }
        defer { deflateEnd(&stream) }

        var destination = Data(capacity: data.count + 64)
        let bufferSize = 16384
        var buffer = [UInt8](repeating: 0, count: bufferSize)

        data.withUnsafeBytes { rawBuffer in
            stream.next_in = UnsafeMutablePointer<Bytef>(mutating: rawBuffer.bindMemory(to: Bytef.self).baseAddress)
            stream.avail_in = uInt(data.count)

            while stream.avail_in > 0 {
                buffer.withUnsafeMutableBytes { outBuffer in
                    stream.next_out = outBuffer.bindMemory(to: Bytef.self).baseAddress
                    stream.avail_out = uInt(bufferSize)
                    deflate(&stream, Z_NO_FLUSH)
                    destination.append(outBuffer.baseAddress!.assumingMemoryBound(to: UInt8.self), count: bufferSize - Int(stream.avail_out))
                }
            }

            repeat {
                buffer.withUnsafeMutableBytes { outBuffer in
                    stream.next_out = outBuffer.bindMemory(to: Bytef.self).baseAddress
                    stream.avail_out = uInt(bufferSize)
                    deflate(&stream, Z_FINISH)
                    destination.append(outBuffer.baseAddress!.assumingMemoryBound(to: UInt8.self), count: bufferSize - Int(stream.avail_out))
                }
            } while stream.avail_out == 0
        }

        return destination
    }

    public static func decompressFlate(_ data: Data) -> Data {
        guard !data.isEmpty else { return Data() }

        // Try raw deflate first (-MAX_WBITS)
        if let decompressed = inflateData(data, windowBits: -MAX_WBITS) {
            return decompressed
        }
        // Fallback to standard zlib (MAX_WBITS)
        if let decompressed = inflateData(data, windowBits: MAX_WBITS) {
            return decompressed
        }
        return data
    }

    private static func inflateData(_ data: Data, windowBits: Int32) -> Data? {
        var stream = z_stream()
        guard inflateInit2_(&stream, windowBits, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else {
            return nil
        }
        defer { inflateEnd(&stream) }

        var destination = Data(capacity: data.count * 2)
        let bufferSize = 16384
        var buffer = [UInt8](repeating: 0, count: bufferSize)

        return data.withUnsafeBytes { rawBuffer -> Data? in
            stream.next_in = UnsafeMutablePointer<Bytef>(mutating: rawBuffer.bindMemory(to: Bytef.self).baseAddress)
            stream.avail_in = uInt(data.count)

            var status: Int32 = Z_OK
            while status == Z_OK {
                buffer.withUnsafeMutableBytes { outBuffer in
                    stream.next_out = outBuffer.bindMemory(to: Bytef.self).baseAddress
                    stream.avail_out = uInt(bufferSize)
                    status = inflate(&stream, Z_SYNC_FLUSH)
                    destination.append(outBuffer.baseAddress!.assumingMemoryBound(to: UInt8.self), count: bufferSize - Int(stream.avail_out))
                }
            }

            return (status == Z_STREAM_END || status == Z_OK) ? destination : nil
        }
    }

    // MARK: - Packet Header
    public static func encodePacketHeader(packetId: UInt32, senderSubclient: UInt32 = 0, recipientSubclient: UInt32 = 0) -> Data {
        let raw = (packetId & 0x3FF) | ((senderSubclient & 0x03) << 10) | ((recipientSubclient & 0x03) << 12)
        return VarInt.encodeVarUInt32(raw)
    }

    public static func decodePacketHeader(data: Data, offset: inout Int) throws -> UInt32 {
        let raw = try VarInt.decodeVarUInt32(data, offset: &offset)
        return raw & 0x3FF
    }

    // MARK: - Batch Framing (0xFE)
    public static func encodeBatch(packets: [Data], compressionAlgo: Int = Int(compressionNone)) -> Data {
        var rawBatch = Data()
        for pk in packets {
            rawBatch.append(VarInt.encodeVarUInt32(UInt32(pk.count)))
            rawBatch.append(pk)
        }

        if compressionAlgo == Int(compressionZlib) {
            let compressed = compressFlate(rawBatch)
            var out = Data([0xFE, 0x00]) // 0xFE + 0x00 (Zlib algorithm byte)
            out.append(compressed)
            return out
        } else if compressionAlgo == Int(compressionNone) {
            var out = Data([0xFE, 0xFF]) // Uncompressed with marker
            out.append(rawBatch)
            return out
        } else {
            var out = Data([0xFE]) // Raw batch without compression byte
            out.append(rawBatch)
            return out
        }
    }

    public static func decodeBatch(_ data: Data) -> [Data] {
        guard data.count >= 2, data[0] == 0xFE else { return [] }

        var payload = data.subdata(in: 1..<data.count)

        if !payload.isEmpty {
            let algoByte = payload[0]
            if algoByte == 0x00 { // Flate / Zlib compressed
                payload = decompressFlate(payload.subdata(in: 1..<payload.count))
            } else if algoByte == 0xFF { // Uncompressed with marker
                payload = payload.subdata(in: 1..<payload.count)
            }
        }

        var packets: [Data] = []
        var offset = 0
        while offset < payload.count {
            do {
                let length = Int(try VarInt.decodeVarUInt32(payload, offset: &offset))
                guard offset + length <= payload.count else { break }
                let pkData = payload.subdata(in: offset..<(offset + length))
                packets.append(pkData)
                offset += length
            } catch {
                break
            }
        }

        return packets
    }

    // MARK: - Packet Serialization
    public static func parseRequestNetworkSettings(_ payload: Data) -> Int32? {
        var offset = 0
        guard let packetId = try? decodePacketHeader(data: payload, offset: &offset),
              packetId == idRequestNetworkSettings,
              offset + 4 <= payload.count else { return nil }

        let clientProtocol = payload.subdata(in: offset..<(offset + 4)).withUnsafeBytes { $0.load(as: Int32.self).bigEndian }
        return clientProtocol
    }

    public static func buildNetworkSettings(
        compressionThreshold: UInt16 = 1,
        compressionAlgorithm: UInt16 = compressionZlib
    ) -> Data {
        var out = encodePacketHeader(packetId: idNetworkSettings)
        var thresh = compressionThreshold.littleEndian
        withUnsafeBytes(of: &thresh) { out.append(contentsOf: $0) }
        var algo = compressionAlgorithm.littleEndian
        withUnsafeBytes(of: &algo) { out.append(contentsOf: $0) }
        out.append(0x00) // client throttle
        out.append(0x00) // threshold
        var scalar: Float32 = 0.0
        withUnsafeBytes(of: &scalar) { out.append(contentsOf: $0) }
        return out
    }

    public static func parseLogin(_ payload: Data) -> (protocolVersion: Int32, displayName: String)? {
        var offset = 0
        guard let packetId = try? decodePacketHeader(data: payload, offset: &offset),
              packetId == idLogin,
              offset + 4 <= payload.count else { return nil }

        let proto = payload.subdata(in: offset..<(offset + 4)).withUnsafeBytes { $0.load(as: Int32.self).bigEndian }
        offset += 4

        let connectionRequest = payload.subdata(in: offset..<payload.count)
        var displayName = "Joueur Console"

        if let text = String(data: connectionRequest, encoding: .utf8) ?? String(data: connectionRequest, encoding: .ascii) {
            let pattern = "\"displayName\"\\s*:\\s*\"([^\"]+)\""
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: text) {
                displayName = String(text[range])
            }
        }

        return (proto, displayName)
    }

    public static func buildPlayStatus(status: Int32 = statusLoginSuccess) -> Data {
        var out = encodePacketHeader(packetId: idPlayStatus)
        var st = status.bigEndian
        withUnsafeBytes(of: &st) { out.append(contentsOf: $0) }
        return out
    }

    public static func buildTransferPacket(address: String, port: UInt16, reloadWorld: Bool = false) -> Data {
        var out = encodePacketHeader(packetId: idTransfer)
        out.append(VarInt.encodeString(address))
        var p = port.littleEndian
        withUnsafeBytes(of: &p) { out.append(contentsOf: $0) }
        out.append(reloadWorld ? 0x01 : 0x00)
        out.append(0x00) // gathering join info: false
        return out
    }

    public static func buildSetEntityMotion(runtimeEntityId: UInt64 = 1) -> Data {
        var out = encodePacketHeader(packetId: idSetEntityMotion)
        out.append(VarInt.encodeVarUInt64(runtimeEntityId))
        out.append(dataFromHex("00000000000000000000000000")) // 3 floats (12 bytes) + 1 byte tick
        return out
    }

    public static func buildResourcePacksInfo(protocolVersion: Int = currentProtocolVersion) -> Data {
        var data = encodePacketHeader(packetId: idResourcePacksInfo)
        data.append(0x00) // forcedToAccept
        data.append(0x00) // hasAddonPacks
        data.append(0x00) // scriptingEnabled

        if protocolVersion >= 818 {
            data.append(0x00) // vibrantVisualsForceDisabled
            data.append(Data(repeating: 0, count: 16)) // worldTemplateId
            data.append(VarInt.encodeString("*")) // worldTemplateVersion: "*"
        }

        if protocolVersion >= 2168 {
            data.append(VarInt.encodeVarUInt32(0)) // resourcePackInfos count
        } else {
            var zero: UInt16 = 0
            withUnsafeBytes(of: &zero) { data.append(contentsOf: $0) }
            withUnsafeBytes(of: &zero) { data.append(contentsOf: $0) }
        }

        return data
    }

    public static func buildResourcePackStack(
        gameVersion: String = "*",
        protocolVersion: Int = currentProtocolVersion
    ) -> Data {
        var data = encodePacketHeader(packetId: idResourcePackStack)
        data.append(0x00) // forcedToAccept

        var zeroUInt32: UInt32 = 0
        if protocolVersion >= 898 {
            data.append(VarInt.encodeVarUInt32(0)) // resourcePacks count
            data.append(VarInt.encodeString(gameVersion.isEmpty ? "*" : gameVersion))
            withUnsafeBytes(of: &zeroUInt32) { data.append(contentsOf: $0) } // experiments count
            data.append(0x00) // experimentsPreviouslyToggled
            data.append(0x00) // hasEditorPacks
        } else if protocolVersion >= 671 {
            data.append(VarInt.encodeVarUInt32(0))
            data.append(VarInt.encodeVarUInt32(0))
            data.append(VarInt.encodeString(gameVersion.isEmpty ? "*" : gameVersion))
            withUnsafeBytes(of: &zeroUInt32) { data.append(contentsOf: $0) }
            data.append(0x00)
            data.append(0x00)
        } else {
            var zeroUInt16: UInt16 = 0
            withUnsafeBytes(of: &zeroUInt16) { data.append(contentsOf: $0) }
            withUnsafeBytes(of: &zeroUInt16) { data.append(contentsOf: $0) }
            data.append(VarInt.encodeString(gameVersion.isEmpty ? "*" : gameVersion))
            withUnsafeBytes(of: &zeroUInt32) { data.append(contentsOf: $0) }
            data.append(0x00)
        }

        return data
    }

    public static func parseResourcePackClientResponse(
        _ payload: Data,
        protocolVersion: Int = currentProtocolVersion
    ) -> Int? {
        var offset = 0
        guard let packetId = try? decodePacketHeader(data: payload, offset: &offset),
              packetId == idResourcePackClientResponse,
              offset < payload.count else { return nil }

        // Try varuint32 first
        var tempOffset = offset
        if let val = try? VarInt.decodeVarUInt32(payload, offset: &tempOffset) {
            let status = Int(val) + 1
            if status == responseStatusHaveAllPacks || status == responseStatusCompleted {
                return status
            }
        }

        // Try single byte
        let byteVal = Int(payload[offset])
        if byteVal == responseStatusHaveAllPacks || byteVal == responseStatusCompleted {
            return byteVal
        }

        // Search markers in payload
        if let str = String(data: payload, encoding: .ascii) {
            if str.contains("downloadingfinished") {
                return responseStatusHaveAllPacks
            } else if str.contains("resourcepackstackfinished") {
                return responseStatusCompleted
            }
        }

        return nil
    }

    // BedrockConnect / Cloudburst StartGame hex vectors
    // Protocol 2168 / 2169 (Minecraft 1.26.40 / 1.26.45) - 225 bytes verified
    private static let startGameHexV2169 = (
        "0201000000000000000000000000000000803f0000803fffffffffffffffff00" +
        "0000000200000200000000000000000000000000000000000000000101080801" +
        "00010f73686f77636f6f7264696e617465730001000000000000000001040000" +
        "0000000000000000000000012a0000000000000000000000000000000005776f" +
        "726c6405776f726c642430303030303030302d303030302d303030302d303030" +
        "302d303030303030303030303030000001000000000000000000000001000a00" +
        "0000000000000000000000000000000000000000000000000000000000000000" +
        "00"
    )

    // Protocol 685-898 (Minecraft 1.21.x)
    private static let startGameHexV685 = (
        "0201000000000000000000000000000000803f0000803fffffffffffffffff" +
        "00000000020000020000000000000000000000000000000000000000010108" +
        "080100010f73686f77636f6f7264696e617465730001010000000000000002" +
        "040000000000000000000000000000012a0000000000000000000000000000" +
        "000000000005776f726c6405776f726c642430303030303030302d30303030" +
        "2d303030302d303030302d3030303030303030303030300000010000000000" +
        "00000000000001000a00000000000000000000000000000000000000000000" +
        "00000000000000"
    )

    // Protocol <= 671 (Minecraft 1.20.x)
    private static let startGameHexV671 = (
        "0201000000000000000000000000000000803f0000803fffffffffffffffff" +
        "00000000020000020000000000000000000000000000000000000000010108" +
        "080100010f73686f77636f6f7264696e617465730001010000000000000002" +
        "040000000000000000000000000000012a0000000000000000000000000000" +
        "05776f726c6405776f726c642430303030303030302d303030302d30303030" +
        "2d303030302d30303030303030303030303000040001000000000000000000" +
        "00000001000a00000000000000000000000000000000000000000000000000" +
        "00000000"
    )

    public static func dataFromHex(_ hex: String) -> Data {
        var data = Data()
        var temp = ""
        for char in hex {
            temp.append(char)
            if temp.count == 2 {
                if let num = UInt8(temp, radix: 16) {
                    data.append(num)
                }
                temp = ""
            }
        }
        return data
    }

    public static func buildStartGame(protocolVersion: Int = currentProtocolVersion) -> Data {
        var out = encodePacketHeader(packetId: idStartGame)
        if protocolVersion >= 2168 {
            out.append(dataFromHex(startGameHexV2169))
        } else if protocolVersion >= 685 {
            out.append(dataFromHex(startGameHexV685))
        } else {
            out.append(dataFromHex(startGameHexV671))
        }
        return out
    }

    public static func buildItemComponent() -> Data {
        var out = encodePacketHeader(packetId: idItemComponent)
        out.append(0x00) // items count: 0
        return out
    }

    public static func buildCreativeContent() -> Data {
        var out = encodePacketHeader(packetId: idCreativeContent)
        out.append(contentsOf: [0x00, 0x00]) // groups: 0, items: 0
        return out
    }

    public static func buildChunkRadiusUpdated(radius: Int32 = 4) -> Data {
        var out = encodePacketHeader(packetId: idChunkRadiusUpdated)
        out.append(VarInt.encodeVarInt32(radius))
        return out
    }

    public static func parseRequestChunkRadius(_ payload: Data) -> Int32? {
        var offset = 0
        guard let packetId = try? decodePacketHeader(data: payload, offset: &offset),
              packetId == idRequestChunkRadius,
              offset < payload.count else { return nil }
        return try? VarInt.decodeVarInt32(payload, offset: &offset)
    }

    // Valid 268-byte empty LevelChunk payload with 258-byte zero biome/heightmap + NBT terminator (0a 00 00)
    private static let emptyChunkPayloadHex = (
        "0000000000850200000000000000000000000000000000000000000000000000" +
        "0000000000000000000000000000000000000000000000000000000000000000" +
        "0000000000000000000000000000000000000000000000000000000000000000" +
        "0000000000000000000000000000000000000000000000000000000000000000" +
        "0000000000000000000000000000000000000000000000000000000000000000" +
        "0000000000000000000000000000000000000000000000000000000000000000" +
        "0000000000000000000000000000000000000000000000000000000000000000" +
        "0000000000000000000000000000000000000000000000000000000000000000" +
        "0000000000000000000a0000"
    )

    public static func buildLevelChunk(chunkX: Int32 = 0, chunkZ: Int32 = 0) -> Data {
        var out = encodePacketHeader(packetId: idLevelChunk)
        out.append(VarInt.encodeVarInt32(chunkX))
        out.append(VarInt.encodeVarInt32(chunkZ))
        out.append(dataFromHex(emptyChunkPayloadHex))
        return out
    }

    public static func buildPlayerSpawn() -> Data {
        return buildPlayStatus(status: statusPlayerSpawn)
    }

    public static func buildUpdateAttributes(runtimeEntityId: UInt64 = 0) -> Data {
        var out = encodePacketHeader(packetId: idUpdateAttributes)
        out.append(VarInt.encodeVarUInt64(runtimeEntityId))
        out.append(dataFromHex("010000000000008044cdcccc3d0000000000008044cdcccc3d126d696e6563726166743a6d6f76656d656e740000"))
        return out
    }
}
