import Foundation

public struct RakNet {
    public static let magic = Data([0x00, 0xff, 0xff, 0x00, 0xfe, 0xfe, 0xfe, 0xfe, 0xfd, 0xfd, 0xfd, 0xfd, 0x12, 0x34, 0x56, 0x78])
    public static let protocolVersion: UInt8 = 11

    public static let idConnectedPing: UInt8 = 0x00
    public static let idUnconnectedPing: UInt8 = 0x01
    public static let idUnconnectedPingOpenConnections: UInt8 = 0x02
    public static let idConnectedPong: UInt8 = 0x03
    public static let idOpenConnectionRequest1: UInt8 = 0x05
    public static let idOpenConnectionReply1: UInt8 = 0x06
    public static let idOpenConnectionRequest2: UInt8 = 0x07
    public static let idOpenConnectionReply2: UInt8 = 0x08
    public static let idConnectionRequest: UInt8 = 0x09
    public static let idConnectionRequestAccepted: UInt8 = 0x10
    public static let idNewIncomingConnection: UInt8 = 0x13
    public static let idDisconnectionNotification: UInt8 = 0x15
    public static let idIncompatibleProtocolVersion: UInt8 = 0x19
    public static let idUnconnectedPong: UInt8 = 0x1C

    public static let idGamePacket: UInt8 = 0xFE

    public static let bitflagDatagram: UInt8 = 0x80
    public static let bitflagAck: UInt8 = 0x40
    public static let bitflagNack: UInt8 = 0x20
    public static let bitflagNeedsBAndAs: UInt8 = 0x04
    public static let splitFlag: UInt8 = 0x10

    public static let reliabilityUnreliable: UInt8 = 0
    public static let reliabilityUnreliableSequenced: UInt8 = 1
    public static let reliabilityReliable: UInt8 = 2
    public static let reliabilityReliableOrdered: UInt8 = 3
    public static let reliabilityReliableSequenced: UInt8 = 4

    // MARK: - Binary Utilities
    public static func encodeUInt24LE(_ val: UInt32) -> Data {
        let v = val & 0xFFFFFF
        return Data([UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF), UInt8((v >> 16) & 0xFF)])
    }

    public static func decodeUInt24LE(_ data: Data, offset: inout Int) throws -> UInt32 {
        guard offset + 3 <= data.count else {
            throw VarIntError.unexpectedEOF
        }
        let b0 = UInt32(data[offset])
        let b1 = UInt32(data[offset + 1])
        let b2 = UInt32(data[offset + 2])
        offset += 3
        return b0 | (b1 << 8) | (b2 << 16)
    }

    public static func encodeAddress(ip: String, port: UInt16) -> Data {
        let parts = ip.split(separator: ".").compactMap { UInt8($0) }
        let octets = parts.count == 4 ? parts : [127, 0, 0, 1]

        var data = Data()
        data.append(0x04) // IPv4
        for oct in octets {
            data.append((~oct) & 0xFF)
        }
        var bigPort = port.bigEndian
        withUnsafeBytes(of: &bigPort) { data.append(contentsOf: $0) }
        return data
    }

    public static func decodeAddress(_ data: Data, offset: inout Int) throws -> (ip: String, port: UInt16) {
        guard offset < data.count else { throw VarIntError.unexpectedEOF }
        let addrType = data[offset]

        if addrType == 4 {
            guard offset + 7 <= data.count else { throw VarIntError.unexpectedEOF }
            let octets = [
                (~data[offset + 1]) & 0xFF,
                (~data[offset + 2]) & 0xFF,
                (~data[offset + 3]) & 0xFF,
                (~data[offset + 4]) & 0xFF
            ]
            let ip = octets.map { String($0) }.joined(separator: ".")
            let portBytes = data.subdata(in: (offset + 5)..<(offset + 7))
            let port = portBytes.withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
            offset += 7
            return (ip, port)
        } else if addrType == 6 {
            guard offset + 29 <= data.count else { throw VarIntError.unexpectedEOF }
            let portBytes = data.subdata(in: (offset + 3)..<(offset + 5))
            let port = portBytes.withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
            offset += 29
            return ("::1", port)
        } else {
            offset = min(offset + 7, data.count)
            return ("127.0.0.1", 19132)
        }
    }

    // MARK: - Unconnected Ping / Pong
    public static func buildUnconnectedPong(pingTime: UInt64, serverGuid: Int64, motd: String) -> Data {
        var data = Data()
        data.append(idUnconnectedPong)
        var pt = pingTime.bigEndian
        withUnsafeBytes(of: &pt) { data.append(contentsOf: $0) }
        var sg = serverGuid.bigEndian
        withUnsafeBytes(of: &sg) { data.append(contentsOf: $0) }
        data.append(magic)
        let motdBytes = Data(motd.utf8)
        var mlen = UInt16(motdBytes.count).bigEndian
        withUnsafeBytes(of: &mlen) { data.append(contentsOf: $0) }
        data.append(motdBytes)
        return data
    }

    public static func parseUnconnectedPong(_ data: Data) -> (pingTime: UInt64, serverGuid: Int64, motd: String)? {
        guard data.count >= 35, data[0] == idUnconnectedPong else { return nil }

        let pt = data.subdata(in: 1..<9).withUnsafeBytes { $0.load(as: UInt64.self).bigEndian }
        let sg = data.subdata(in: 9..<17).withUnsafeBytes { $0.load(as: Int64.self).bigEndian }
        let magicBytes = data.subdata(in: 17..<33)
        guard magicBytes == magic else { return nil }

        let mlen = Int(data.subdata(in: 33..<35).withUnsafeBytes { $0.load(as: UInt16.self).bigEndian })
        guard data.count >= 35 + mlen else { return nil }
        let motdData = data.subdata(in: 35..<(35 + mlen))
        let motd = String(data: motdData, encoding: .utf8) ?? ""
        return (pt, sg, motd)
    }

    // MARK: - Handshake Packets (Open Connection 1 & 2)
    public static func parseOpenConnectionRequest1(_ data: Data) -> (protocolVersion: UInt8, mtu: UInt16)? {
        guard data.count >= 18, data[0] == idOpenConnectionRequest1 else { return nil }
        let magicBytes = data.subdata(in: 1..<17)
        guard magicBytes == magic else { return nil }
        let proto = data[17]
        let mtu = UInt16(min(data.count + 28, 1492))
        return (proto, mtu)
    }

    public static func buildOpenConnectionReply1(serverGuid: Int64, mtu: UInt16) -> Data {
        var data = Data()
        data.append(idOpenConnectionReply1)
        data.append(magic)
        var sg = serverGuid.bigEndian
        withUnsafeBytes(of: &sg) { data.append(contentsOf: $0) }
        data.append(0x00) // security flag
        var mtuVal = mtu.bigEndian
        withUnsafeBytes(of: &mtuVal) { data.append(contentsOf: $0) }
        return data
    }

    public static func parseOpenConnectionRequest2(_ data: Data) -> (serverAddress: (String, UInt16), mtu: UInt16, clientGuid: Int64)? {
        guard data.count >= 34, data[0] == idOpenConnectionRequest2 else { return nil }
        let magicBytes = data.subdata(in: 1..<17)
        guard magicBytes == magic else { return nil }

        var offset = 17
        do {
            let serverAddr = try decodeAddress(data, offset: &offset)
            guard offset + 10 <= data.count else { return nil }
            let mtu = data.subdata(in: offset..<(offset + 2)).withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
            let clientGuid = data.subdata(in: (offset + 2)..<(offset + 10)).withUnsafeBytes { $0.load(as: Int64.self).bigEndian }
            return (serverAddr, mtu, clientGuid)
        } catch {
            return nil
        }
    }

    public static func buildOpenConnectionReply2(serverGuid: Int64, clientIp: String, clientPort: UInt16, mtu: UInt16) -> Data {
        var data = Data()
        data.append(idOpenConnectionReply2)
        data.append(magic)
        var sg = serverGuid.bigEndian
        withUnsafeBytes(of: &sg) { data.append(contentsOf: $0) }
        data.append(encodeAddress(ip: clientIp, port: clientPort))
        var mtuVal = mtu.bigEndian
        withUnsafeBytes(of: &mtuVal) { data.append(contentsOf: $0) }
        data.append(0x00) // security flag
        return data
    }

    // MARK: - Session Packets
    public static func parseConnectionRequest(_ data: Data) -> (clientGuid: Int64, pingTime: Int64)? {
        guard data.count >= 18, data[0] == idConnectionRequest else { return nil }
        let cg = data.subdata(in: 1..<9).withUnsafeBytes { $0.load(as: Int64.self).bigEndian }
        let pt = data.subdata(in: 9..<17).withUnsafeBytes { $0.load(as: Int64.self).bigEndian }
        return (cg, pt)
    }

    public static func buildConnectionRequestAccepted(clientIp: String, clientPort: UInt16, pingTime: Int64, pongTime: Int64? = nil) -> Data {
        var data = Data()
        data.append(idConnectionRequestAccepted)
        data.append(encodeAddress(ip: clientIp, port: clientPort))
        var zeroIndex: UInt16 = 0
        withUnsafeBytes(of: &zeroIndex) { data.append(contentsOf: $0) }

        // 10 internal system addresses
        let sysAddr = encodeAddress(ip: "127.0.0.1", port: 0)
        for _ in 0..<10 {
            data.append(sysAddr)
        }

        var pt = pingTime.bigEndian
        withUnsafeBytes(of: &pt) { data.append(contentsOf: $0) }
        let pong = pongTime ?? Int64(Date().timeIntervalSince1970 * 1000)
        var pgt = pong.bigEndian
        withUnsafeBytes(of: &pgt) { data.append(contentsOf: $0) }
        return data
    }

    public static func parseConnectedPing(_ data: Data) -> Int64? {
        guard data.count >= 9, data[0] == idConnectedPing else { return nil }
        return data.subdata(in: 1..<9).withUnsafeBytes { $0.load(as: Int64.self).bigEndian }
    }

    public static func buildConnectedPong(pingTime: Int64, pongTime: Int64? = nil) -> Data {
        var data = Data()
        data.append(idConnectedPong)
        var pt = pingTime.bigEndian
        withUnsafeBytes(of: &pt) { data.append(contentsOf: $0) }
        let pong = pongTime ?? Int64(Date().timeIntervalSince1970 * 1000)
        var pgt = pong.bigEndian
        withUnsafeBytes(of: &pgt) { data.append(contentsOf: $0) }
        return data
    }

    // MARK: - Datagrams & Encapsulated Packets
    public static func buildDatagram(sequenceNumber: UInt32, frames: [EncapsulatedPacket]) -> Data {
        var data = Data()
        data.append(bitflagDatagram | bitflagNeedsBAndAs) // 0x84
        data.append(encodeUInt24LE(sequenceNumber))
        for f in frames {
            data.append(f.serialize())
        }
        return data
    }

    public static func parseDatagram(_ data: Data) -> (sequenceNumber: UInt32, frames: [EncapsulatedPacket])? {
        guard data.count >= 4, (data[0] & bitflagDatagram) != 0 else { return nil }

        var offset = 1
        guard let seqNum = try? decodeUInt24LE(data, offset: &offset) else { return nil }
        var frames: [EncapsulatedPacket] = []

        while offset < data.count {
            guard let frame = try? EncapsulatedPacket.deserialize(data: data, offset: &offset) else {
                break
            }
            frames.append(frame)
        }

        return (seqNum, frames)
    }

    // MARK: - ACK / NACK
    public static func buildAck(sequenceNumbers: [UInt32]) -> Data {
        let flag = bitflagAck | bitflagDatagram // 0xC0
        guard !sequenceNumbers.isEmpty else {
            return Data([flag, 0x00, 0x00])
        }

        let sortedSeqs = Array(Set(sequenceNumbers)).sorted()
        var records: [(start: UInt32, end: UInt32)] = []

        var start = sortedSeqs[0]
        var end = start

        for seq in sortedSeqs.dropFirst() {
            if seq == end + 1 {
                end = seq
            } else {
                records.append((start, end))
                start = seq
                end = seq
            }
        }
        records.append((start, end))

        var data = Data([flag])
        var recCount = UInt16(records.count).bigEndian
        withUnsafeBytes(of: &recCount) { data.append(contentsOf: $0) }

        for r in records {
            if r.start == r.end {
                data.append(0x01) // single
                data.append(encodeUInt24LE(r.start))
            } else {
                data.append(0x00) // range
                data.append(encodeUInt24LE(r.start))
                data.append(encodeUInt24LE(r.end))
            }
        }

        return data
    }

    public static func parseAck(_ data: Data) -> [UInt32] {
        let expected = bitflagAck | bitflagDatagram
        guard data.count >= 3, (data[0] & expected) == expected else { return [] }

        let recCount = Int(data.subdata(in: 1..<3).withUnsafeBytes { $0.load(as: UInt16.self).bigEndian })
        var offset = 3
        var seqs: [UInt32] = []

        for _ in 0..<recCount {
            guard offset < data.count else { break }
            let recType = data[offset]
            offset += 1
            if recType == 0x01 { // Single
                guard offset + 3 <= data.count else { break }
                if let seq = try? decodeUInt24LE(data, offset: &offset) {
                    seqs.append(seq)
                }
            } else if recType == 0x00 { // Range
                guard offset + 6 <= data.count else { break }
                if let start = try? decodeUInt24LE(data, offset: &offset),
                   let end = try? decodeUInt24LE(data, offset: &offset) {
                    seqs.append(contentsOf: start...end)
                }
            }
        }

        return seqs
    }
}

// MARK: - EncapsulatedPacket
public class EncapsulatedPacket {
    public var content: Data
    public var reliability: UInt8
    public var messageIndex: UInt32
    public var orderIndex: UInt32
    public var orderChannel: UInt8
    public var split: Bool
    public var splitCount: UInt32
    public var splitId: UInt16
    public var splitIndex: UInt32

    public init(
        content: Data,
        reliability: UInt8 = RakNet.reliabilityReliableOrdered,
        messageIndex: UInt32 = 0,
        orderIndex: UInt32 = 0,
        orderChannel: UInt8 = 0,
        split: Bool = false,
        splitCount: UInt32 = 0,
        splitId: UInt16 = 0,
        splitIndex: UInt32 = 0
    ) {
        self.content = content
        self.reliability = reliability
        self.messageIndex = messageIndex
        self.orderIndex = orderIndex
        self.orderChannel = orderChannel
        self.split = split
        self.splitCount = splitCount
        self.splitId = splitId
        self.splitIndex = splitIndex
    }

    public func serialize() -> Data {
        var header = (reliability & 0x07) << 5
        if split {
            header |= RakNet.splitFlag
        }

        var out = Data([header])
        var bitLength = UInt16(content.count << 3).bigEndian
        withUnsafeBytes(of: &bitLength) { out.append(contentsOf: $0) }

        // Reliable
        if reliability == RakNet.reliabilityReliable ||
           reliability == RakNet.reliabilityReliableOrdered ||
           reliability == RakNet.reliabilityReliableSequenced {
            out.append(RakNet.encodeUInt24LE(messageIndex))
        }

        // Sequenced
        if reliability == RakNet.reliabilityUnreliableSequenced ||
           reliability == RakNet.reliabilityReliableSequenced {
            out.append(RakNet.encodeUInt24LE(0))
        }

        // Ordered
        if reliability == RakNet.reliabilityReliableOrdered ||
           reliability == RakNet.reliabilityReliableSequenced {
            out.append(RakNet.encodeUInt24LE(orderIndex))
            out.append(orderChannel)
        }

        // Split
        if split {
            var count = splitCount.bigEndian
            withUnsafeBytes(of: &count) { out.append(contentsOf: $0) }
            var sid = splitId.bigEndian
            withUnsafeBytes(of: &sid) { out.append(contentsOf: $0) }
            var sidx = splitIndex.bigEndian
            withUnsafeBytes(of: &sidx) { out.append(contentsOf: $0) }
        }

        out.append(content)
        return out
    }

    public static func deserialize(data: Data, offset: inout Int) throws -> EncapsulatedPacket {
        guard offset + 3 <= data.count else { throw VarIntError.unexpectedEOF }
        let header = data[offset]
        let reliability = (header >> 5) & 0x07
        let isSplit = (header & RakNet.splitFlag) != 0

        let bitLength = data.subdata(in: (offset + 1)..<(offset + 3)).withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
        let contentLen = Int(bitLength >> 3)
        offset += 3

        var messageIndex: UInt32 = 0
        if reliability == RakNet.reliabilityReliable ||
           reliability == RakNet.reliabilityReliableOrdered ||
           reliability == RakNet.reliabilityReliableSequenced {
            messageIndex = try RakNet.decodeUInt24LE(data, offset: &offset)
        }

        if reliability == RakNet.reliabilityUnreliableSequenced ||
           reliability == RakNet.reliabilityReliableSequenced {
            _ = try RakNet.decodeUInt24LE(data, offset: &offset)
        }

        var orderIndex: UInt32 = 0
        var orderChannel: UInt8 = 0
        if reliability == RakNet.reliabilityReliableOrdered ||
           reliability == RakNet.reliabilityReliableSequenced {
            orderIndex = try RakNet.decodeUInt24LE(data, offset: &offset)
            guard offset < data.count else { throw VarIntError.unexpectedEOF }
            orderChannel = data[offset]
            offset += 1
        }

        var splitCount: UInt32 = 0
        var splitId: UInt16 = 0
        var splitIndex: UInt32 = 0

        if isSplit {
            guard offset + 10 <= data.count else { throw VarIntError.unexpectedEOF }
            splitCount = data.subdata(in: offset..<(offset + 4)).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            splitId = data.subdata(in: (offset + 4)..<(offset + 6)).withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
            splitIndex = data.subdata(in: (offset + 6)..<(offset + 10)).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            offset += 10
        }

        guard offset + contentLen <= data.count else { throw VarIntError.unexpectedEOF }
        let content = data.subdata(in: offset..<(offset + contentLen))
        offset += contentLen

        return EncapsulatedPacket(
            content: content,
            reliability: reliability,
            messageIndex: messageIndex,
            orderIndex: orderIndex,
            orderChannel: orderChannel,
            split: isSplit,
            splitCount: splitCount,
            splitId: splitId,
            splitIndex: splitIndex
        )
    }
}
