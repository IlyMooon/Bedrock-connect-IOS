import Foundation

public final class ClientSession {
    public let ip: String
    public let port: UInt16
    public var mtu: Int
    public var clientGuid: Int64 = 0
    public var serverSeqNum: UInt32 = 0
    public var messageIndex: UInt32 = 0
    public var orderIndex: UInt32 = 0
    public var compressionNegotiated: Bool = false
    public var compressionAlgo: UInt16 = BedrockProtocol.compressionZlib
    public var transferred: Bool = false
    public var worldSpawned: Bool = false
    public var transferScheduled: Bool = false
    public var transferWorkItem: DispatchWorkItem?
    public var playerName: String = "Joueur Console"
    public var lastActive: Date = Date()
    public var protocolVersion: Int = BedrockProtocol.currentProtocolVersion

    // Split frame reassembly buffers: splitId -> [splitIndex: Data]
    public var splitPackets: [UInt16: [UInt32: Data]] = [:]
    public var splitCounts: [UInt16: UInt32] = [:]

    public init(ip: String, port: UInt16, mtu: Int = 1400) {
        self.ip = ip
        self.port = port
        self.mtu = mtu
    }

    public func nextSeqNum() -> UInt32 {
        let current = serverSeqNum
        serverSeqNum = (serverSeqNum + 1) & 0xFFFFFF
        return current
    }

    public func nextMessageIndex() -> UInt32 {
        let current = messageIndex
        messageIndex = (messageIndex + 1) & 0xFFFFFF
        return current
    }

    public func nextOrderIndex() -> UInt32 {
        let current = orderIndex
        orderIndex = (orderIndex + 1) & 0xFFFFFF
        return current
    }
}
