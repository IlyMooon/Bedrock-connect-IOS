import Foundation
#if canImport(UIKit)
import UIKit
#endif

public final class BedrockTransferServer: @unchecked Sendable {
    public var bindIp: String
    public var bindPort: UInt16
    public var targetHost: String
    public var targetPort: UInt16
    public var serverName: String
    public var subName: String
    public var protocolVersion: Int
    public var versionString: String
    public var serverGuid: Int64

    public var clonedMotd: String?
    public private(set) var isRunning: Bool = false

    public var onLog: ((String, String) -> Void)?
    public var onPlayerDetected: ((String, String) -> Void)?
    public var onTransferSuccess: ((String, String, UInt16) -> Void)?

    private var listenSock: Int32 = -1
    private var broadcastSock: Int32 = -1
    private var sessions: [String: ClientSession] = [:]
    private let sessionLock = NSLock()

    private var listenThread: Thread?
    private var broadcastThread: Thread?

    #if canImport(UIKit)
    private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid
    #endif

    public init(
        bindIp: String = "0.0.0.0",
        bindPort: UInt16 = 19132,
        targetHost: String = "geo.hivebedrock.network",
        targetPort: UInt16 = 19132,
        serverName: String = "Bedrock DirectConnect",
        subName: String = "Cliquez pour rejoindre",
        protocolVersion: Int = BedrockProtocol.currentProtocolVersion,
        versionString: String = BedrockProtocol.currentVersionString
    ) {
        self.bindIp = bindIp
        self.bindPort = bindPort
        self.targetHost = targetHost
        self.targetPort = targetPort
        self.serverName = serverName
        self.subName = subName
        self.protocolVersion = protocolVersion
        self.versionString = versionString
        self.serverGuid = Int64.random(in: 10000000...99999999)
    }

    public func log(_ message: String, level: String = "INFO") {
        if let onLog = onLog {
            DispatchQueue.main.async {
                onLog(message, level)
            }
        } else {
            print("[\(level)] \(message)")
        }
    }

    // MARK: - MOTD Generation
    public func getMotd() -> String {
        if let cloned = clonedMotd {
            var tokens = cloned.components(separatedBy: ";")
            if tokens.count >= 10 {
                if tokens.count > 10 {
                    tokens[10] = String(bindPort)
                }
                if tokens.count > 11 {
                    tokens[11] = String(bindPort)
                }
                return tokens.joined(separator: ";")
            }
            return cloned
        }

        let cleanName = "§e✦ \(serverName)"
        let sub = "§a\(subName) §7[\(targetHost):\(targetPort)]"
        return "MCPE;\(cleanName);\(protocolVersion);\(versionString);1;100;\(serverGuid);\(sub);Survival;1;\(bindPort);\(bindPort);"
    }

    public func updateTargetMotd() {
        let res = BedrockQuery.pingSync(host: targetHost, port: targetPort, timeout: 2.0)
        if res.online && !res.rawMotd.isEmpty {
            self.clonedMotd = res.rawMotd
            if !res.serverName.isEmpty { self.serverName = res.serverName }
            if !res.subName.isEmpty { self.subName = res.subName }
            if let p = Int(res.protocolVersion), p > 0 { self.protocolVersion = p }
            if !res.versionName.isEmpty && res.versionName != "Unknown" { self.versionString = res.versionName }
            log("🎯 MOTD du serveur cible cloné : \(res.cleanServerName)", level: "SUCCESS")
        } else {
            log("Utilisation du MOTD configuré par défaut pour la diffusion.", level: "DEBUG")
        }
    }

    // MARK: - Start & Stop
    public func start() {
        guard !isRunning else { return }
        isRunning = true

        #if canImport(UIKit)
        beginBackgroundTask()
        #endif

        // Fetch remote MOTD asynchronously
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.updateTargetMotd()
        }

        // Setup listening socket
        listenSock = socket(AF_INET, SOCK_DGRAM, 0)
        guard listenSock >= 0 else {
            log("Impossible de créer la socket d'écoute UDP", level: "ERROR")
            isRunning = false
            return
        }

        var opt: Int32 = 1
        setsockopt(listenSock, SOL_SOCKET, SO_REUSEADDR, &opt, socklen_t(MemoryLayout<Int32>.size))
        setsockopt(listenSock, SOL_SOCKET, SO_REUSEPORT, &opt, socklen_t(MemoryLayout<Int32>.size))

        var bindAddr = sockaddr_in()
        bindAddr.sin_family = sa_family_t(AF_INET)
        bindAddr.sin_port = bindPort.bigEndian
        bindAddr.sin_addr.s_addr = INADDR_ANY

        let bindRes = withUnsafePointer(to: &bindAddr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(listenSock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        guard bindRes == 0 else {
            let err = String(cString: strerror(errno))
            log("Impossible de lier le port UDP \(bindPort) : \(err)", level: "ERROR")
            close(listenSock)
            listenSock = -1
            isRunning = false
            return
        }

        let interfaces = BedrockTransferServer.getLocalIPv4Interfaces()
        let ipList = interfaces.map { "\($0.name): \($0.ipAddress)" }.joined(separator: ", ")
        log("🌐 Écoute UDP active sur 0.0.0.0:\(bindPort) (Binding toutes interfaces / INADDR_ANY)", level: "SUCCESS")
        if !ipList.isEmpty {
            log("📍 IP locale détectée (Mac / Simulateur) : \(ipList)", level: "INFO")
            if let primary = BedrockTransferServer.getPrimaryLocalIP() {
                log("🎮 Vos autres appareils (consoles, téléphones) peuvent se connecter via \(primary):\(bindPort)", level: "INFO")
            }
        }
        log("🎯 Redirection automatique configurée vers : \(targetHost):\(targetPort)", level: "INFO")

        // Setup broadcast socket
        broadcastSock = socket(AF_INET, SOCK_DGRAM, 0)
        if broadcastSock >= 0 {
            var bcastOpt: Int32 = 1
            setsockopt(broadcastSock, SOL_SOCKET, SO_BROADCAST, &bcastOpt, socklen_t(MemoryLayout<Int32>.size))
        }

        // Start threads
        listenThread = Thread { [weak self] in
            self?.listenLoop()
        }
        listenThread?.name = "BedrockListenThread"
        listenThread?.start()

        broadcastThread = Thread { [weak self] in
            self?.broadcastLoop()
        }
        broadcastThread?.name = "BedrockBroadcastThread"
        broadcastThread?.start()
    }

    public func stop() {
        guard isRunning else { return }
        isRunning = false

        if listenSock >= 0 {
            close(listenSock)
            listenSock = -1
        }
        if broadcastSock >= 0 {
            close(broadcastSock)
            broadcastSock = -1
        }

        sessionLock.lock()
        sessions.removeAll()
        sessionLock.unlock()

        log("Serveur de redirection arrêté.", level: "INFO")

        #if canImport(UIKit)
        endBackgroundTask()
        #endif
    }

    #if canImport(UIKit)
    private func beginBackgroundTask() {
        backgroundTaskId = UIApplication.shared.beginBackgroundTask(withName: "BedrockTransferServer") { [weak self] in
            self?.endBackgroundTask()
        }
    }

    private func endBackgroundTask() {
        if backgroundTaskId != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskId)
            backgroundTaskId = .invalid
        }
    }
    #endif

    // MARK: - LAN Discovery Broadcaster
    private func broadcastLoop() {
        while isRunning && broadcastSock >= 0 {
            let motd = getMotd()
            let pingTime = UInt64(Date().timeIntervalSince1970 * 1000)
            let packet = RakNet.buildUnconnectedPong(pingTime: pingTime, serverGuid: serverGuid, motd: motd)

            var targets: [in_addr_t] = [inet_addr("255.255.255.255")]
            for iface in BedrockTransferServer.getLocalIPv4Interfaces() {
                if let b = iface.broadcastAddress, !b.isEmpty {
                    let a = inet_addr(b)
                    if a != INADDR_NONE && !targets.contains(a) {
                        targets.append(a)
                    }
                }
            }

            for targetAddr in targets {
                var bcastAddr = sockaddr_in()
                bcastAddr.sin_family = sa_family_t(AF_INET)
                bcastAddr.sin_port = bindPort.bigEndian
                bcastAddr.sin_addr.s_addr = targetAddr

                _ = packet.withUnsafeBytes { raw in
                    withUnsafePointer(to: &bcastAddr) {
                        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                            sendto(broadcastSock, raw.baseAddress, raw.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                        }
                    }
                }
            }

            Thread.sleep(forTimeInterval: 1.0)
        }
    }

    // MARK: - Listener Loop
    private func listenLoop() {
        var buffer = [UInt8](repeating: 0, count: 65535)

        while isRunning && listenSock >= 0 {
            var clientAddr = sockaddr_in()
            var addrLen = socklen_t(MemoryLayout<sockaddr_in>.size)

            let bytesRead = withUnsafeMutablePointer(to: &clientAddr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    recvfrom(listenSock, &buffer, buffer.count, 0, $0, &addrLen)
                }
            }

            guard bytesRead > 0 else { continue }

            let data = Data(buffer[0..<bytesRead])
            let clientIp = String(cString: inet_ntoa(clientAddr.sin_addr))
            let clientPort = clientAddr.sin_port.bigEndian

            handlePacket(data: data, clientIp: clientIp, clientPort: clientPort, clientAddr: clientAddr)
        }
    }

    private func sendRaw(data: Data, clientAddr: inout sockaddr_in) {
        guard listenSock >= 0 else { return }
        _ = data.withUnsafeBytes { raw in
            withUnsafePointer(to: &clientAddr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    sendto(listenSock, raw.baseAddress, raw.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
    }

    private func getOrCreateSession(ip: String, port: UInt16) -> ClientSession {
        let key = "\(ip):\(port)"
        sessionLock.lock()
        defer { sessionLock.unlock() }
        if let session = sessions[key] {
            session.lastActive = Date()
            return session
        }
        let session = ClientSession(ip: ip, port: port)
        sessions[key] = session
        return session
    }

    // MARK: - Packet Handling
    private func handlePacket(data: Data, clientIp: String, clientPort: UInt16, clientAddr: sockaddr_in) {
        var addr = clientAddr
        guard !data.isEmpty else { return }
        let packetId = data[0]

        // 1. Unconnected Ping (0x01 or 0x02)
        if packetId == RakNet.idUnconnectedPing || packetId == RakNet.idUnconnectedPingOpenConnections {
            let pingTime = data.count >= 9 ? data.subdata(in: 1..<9).withUnsafeBytes { $0.load(as: UInt64.self).bigEndian } : UInt64(Date().timeIntervalSince1970 * 1000)
            let pong = RakNet.buildUnconnectedPong(pingTime: pingTime, serverGuid: serverGuid, motd: getMotd())
            sendRaw(data: pong, clientAddr: &addr)
            return
        }

        // 2. Open Connection Request 1 (0x05)
        if packetId == RakNet.idOpenConnectionRequest1 {
            if let req = RakNet.parseOpenConnectionRequest1(data) {
                let reply = RakNet.buildOpenConnectionReply1(serverGuid: serverGuid, mtu: req.mtu)
                sendRaw(data: reply, clientAddr: &addr)
                log("Console détectée (\(clientIp)) - Étape 1/2 négociée (MTU \(req.mtu))", level: "DEBUG")
            }
            return
        }

        // 3. Open Connection Request 2 (0x07)
        if packetId == RakNet.idOpenConnectionRequest2 {
            if let req = RakNet.parseOpenConnectionRequest2(data) {
                let session = getOrCreateSession(ip: clientIp, port: clientPort)
                session.mtu = Int(req.mtu)
                session.clientGuid = req.clientGuid

                let reply = RakNet.buildOpenConnectionReply2(serverGuid: serverGuid, clientIp: clientIp, clientPort: clientPort, mtu: req.mtu)
                sendRaw(data: reply, clientAddr: &addr)
                log("Handshake RakNet validé avec la console (\(clientIp))", level: "DEBUG")
            }
            return
        }

        // 4. Datagram (0x80)
        if (packetId & RakNet.bitflagDatagram) != 0 {
            let session = getOrCreateSession(ip: clientIp, port: clientPort)
            if let (seq, frames) = RakNet.parseDatagram(data) {
                // Send immediate ACK
                let ack = RakNet.buildAck(sequenceNumbers: [seq])
                sendRaw(data: ack, clientAddr: &addr)

                // Process frames
                for frame in frames {
                    handleFrame(frame: frame, session: session, clientAddr: &addr)
                }
            }
        }
    }

    private func sendDatagram(session: ClientSession, frames: [EncapsulatedPacket], clientAddr: inout sockaddr_in) {
        let datagram = RakNet.buildDatagram(sequenceNumber: session.nextSeqNum(), frames: frames)
        sendRaw(data: datagram, clientAddr: &clientAddr)
    }

    private func handleFrame(frame: EncapsulatedPacket, session: ClientSession, clientAddr: inout sockaddr_in) {
        var payload = frame.content

        // Split packet reassembly
        if frame.split {
            if session.splitPackets[frame.splitId] == nil {
                session.splitPackets[frame.splitId] = [:]
                session.splitCounts[frame.splitId] = frame.splitCount
            }
            session.splitPackets[frame.splitId]?[frame.splitIndex] = frame.content

            let count = session.splitCounts[frame.splitId] ?? 0
            let currentParts = session.splitPackets[frame.splitId]?.count ?? 0
            if currentParts < count {
                return // Waiting for more fragments
            }

            var reassembled = Data()
            for idx in 0..<count {
                if let part = session.splitPackets[frame.splitId]?[idx] {
                    reassembled.append(part)
                }
            }
            session.splitPackets.removeValue(forKey: frame.splitId)
            session.splitCounts.removeValue(forKey: frame.splitId)
            payload = reassembled
        }

        guard !payload.isEmpty else { return }
        let pid = payload[0]

        // 1. Connection Request (0x09)
        if pid == RakNet.idConnectionRequest {
            if let req = RakNet.parseConnectionRequest(payload) {
                let accepted = RakNet.buildConnectionRequestAccepted(clientIp: session.ip, clientPort: session.port, pingTime: req.pingTime)
                let respFrame = EncapsulatedPacket(
                    content: accepted,
                    reliability: RakNet.reliabilityReliableOrdered,
                    messageIndex: session.nextMessageIndex(),
                    orderIndex: session.nextOrderIndex()
                )
                sendDatagram(session: session, frames: [respFrame], clientAddr: &clientAddr)
                log("Session console acceptée (0x10 envoyé)", level: "DEBUG")
            }
            return
        }

        // 2. New Incoming Connection (0x13)
        if pid == RakNet.idNewIncomingConnection {
            log("Session RakNet connectée avec succès avec \(session.ip)", level: "INFO")
            return
        }

        // 3. Connected Ping (0x00)
        if pid == RakNet.idConnectedPing {
            if let pingTime = RakNet.parseConnectedPing(payload) {
                let pong = RakNet.buildConnectedPong(pingTime: pingTime)
                let respFrame = EncapsulatedPacket(
                    content: pong,
                    reliability: RakNet.reliabilityReliableOrdered,
                    messageIndex: session.nextMessageIndex(),
                    orderIndex: session.nextOrderIndex()
                )
                sendDatagram(session: session, frames: [respFrame], clientAddr: &clientAddr)
            }
            return
        }

        // 4. Disconnection Notification (0x15)
        if pid == RakNet.idDisconnectionNotification {
            log("Déconnexion du client \(session.ip)", level: "INFO")
            sessionLock.lock()
            sessions.removeValue(forKey: "\(session.ip):\(session.port)")
            sessionLock.unlock()
            return
        }

        // 5. Game Packet Batch (0xFE)
        if pid == RakNet.idGamePacket {
            handleGameBatch(batchData: payload, session: session, clientAddr: &clientAddr)
        }
    }

    private func handleGameBatch(batchData: Data, session: ClientSession, clientAddr: inout sockaddr_in) {
        let gamePackets = BedrockProtocol.decodeBatch(batchData)

        for pk in gamePackets {
            guard !pk.isEmpty else { continue }
            var offset = 0
            guard let packetId = try? BedrockProtocol.decodePacketHeader(data: pk, offset: &offset) else { continue }

            // Case A: RequestNetworkSettings (ID 193)
            if packetId == BedrockProtocol.idRequestNetworkSettings {
                if let proto = BedrockProtocol.parseRequestNetworkSettings(pk) {
                    session.protocolVersion = Int(proto)
                    log("Paramètres réseau demandés par le client (Protocole v\(proto))", level: "DEBUG")
                }

                let netSettingsPk = BedrockProtocol.buildNetworkSettings(
                    compressionThreshold: 1,
                    compressionAlgorithm: BedrockProtocol.compressionZlib
                )
                let batchResp = BedrockProtocol.encodeBatch(packets: [netSettingsPk], compressionAlgo: -1)
                let respFrame = EncapsulatedPacket(
                    content: batchResp,
                    reliability: RakNet.reliabilityReliableOrdered,
                    messageIndex: session.nextMessageIndex(),
                    orderIndex: session.nextOrderIndex()
                )
                sendDatagram(session: session, frames: [respFrame], clientAddr: &clientAddr)
                session.compressionNegotiated = true
                log("Paramètres réseau envoyés au client (Compression Zlib activée)", level: "DEBUG")
            }

            // Case B: LoginPacket (ID 1)
            else if packetId == BedrockProtocol.idLogin {
                let pName = BedrockProtocol.parseLogin(pk)?.displayName ?? "Joueur Console"
                session.playerName = pName

                log("🎮 Joueur console connecté : \(pName) (\(session.ip))", level: "SUCCESS")
                DispatchQueue.main.async { [weak self] in
                    self?.onPlayerDetected?(pName, session.ip)
                }

                let playStatusPk = BedrockProtocol.buildPlayStatus(status: BedrockProtocol.statusLoginSuccess)
                let motionPk = BedrockProtocol.buildSetEntityMotion(runtimeEntityId: 1)
                let packsInfoPk = BedrockProtocol.buildResourcePacksInfo(protocolVersion: session.protocolVersion)

                let loginBatch = BedrockProtocol.encodeBatch(
                    packets: [playStatusPk, motionPk, packsInfoPk],
                    compressionAlgo: session.compressionNegotiated ? Int(BedrockProtocol.compressionZlib) : Int(BedrockProtocol.compressionNone)
                )
                let respFrame = EncapsulatedPacket(
                    content: loginBatch,
                    reliability: RakNet.reliabilityReliableOrdered,
                    messageIndex: session.nextMessageIndex(),
                    orderIndex: session.nextOrderIndex()
                )
                sendDatagram(session: session, frames: [respFrame], clientAddr: &clientAddr)
                log("📦 Envoi de ResourcePacksInfo (dégagement de l'écran des packs)...", level: "DEBUG")
            }

            // Case C: ResourcePackClientResponse (ID 8)
            else if packetId == BedrockProtocol.idResourcePackClientResponse {
                let status = BedrockProtocol.parseResourcePackClientResponse(pk, protocolVersion: session.protocolVersion)

                if status == BedrockProtocol.responseStatusHaveAllPacks {
                    // Client verified resource packs -> Send ResourcePackStack ONLY
                    let stackPk = BedrockProtocol.buildResourcePackStack(gameVersion: "*", protocolVersion: session.protocolVersion)
                    let stackBatch = BedrockProtocol.encodeBatch(
                        packets: [stackPk],
                        compressionAlgo: session.compressionNegotiated ? Int(BedrockProtocol.compressionZlib) : Int(BedrockProtocol.compressionNone)
                    )
                    let respFrame = EncapsulatedPacket(
                        content: stackBatch,
                        reliability: RakNet.reliabilityReliableOrdered,
                        messageIndex: session.nextMessageIndex(),
                        orderIndex: session.nextOrderIndex()
                    )
                    sendDatagram(session: session, frames: [respFrame], clientAddr: &clientAddr)
                    log("📦 Packs validés par la console. Envoi de la pile de packs...", level: "INFO")
                } else if status == BedrockProtocol.responseStatusCompleted {
                    // Client finished loading packs -> Enter empty void world (StartGame + LevelChunks + PlayerSpawn + UpdateAttributes)
                    session.worldSpawned = true
                    log("🌍 Sas activé : Génération du monde sas sans chunk...", level: "INFO")

                    let startPk = BedrockProtocol.buildStartGame(protocolVersion: session.protocolVersion)
                    let itemCompPk = BedrockProtocol.buildItemComponent()
                    let creativePk = BedrockProtocol.buildCreativeContent()

                    var worldPackets: [Data] = [startPk, itemCompPk, creativePk]

                    // Send 36 empty level chunks (-3 to 2 on X and Z) matching BedrockConnect spawn grid
                    for x in -3..<3 {
                        for z in -3..<3 {
                            worldPackets.append(BedrockProtocol.buildLevelChunk(chunkX: Int32(x), chunkZ: Int32(z)))
                        }
                    }

                    worldPackets.append(BedrockProtocol.buildPlayerSpawn())
                    worldPackets.append(BedrockProtocol.buildUpdateAttributes())

                    let worldBatch = BedrockProtocol.encodeBatch(
                        packets: worldPackets,
                        compressionAlgo: session.compressionNegotiated ? Int(BedrockProtocol.compressionZlib) : Int(BedrockProtocol.compressionNone)
                    )
                    let respFrame = EncapsulatedPacket(
                        content: worldBatch,
                        reliability: RakNet.reliabilityReliableOrdered,
                        messageIndex: session.nextMessageIndex(),
                        orderIndex: session.nextOrderIndex()
                    )
                    sendDatagram(session: session, frames: [respFrame], clientAddr: &clientAddr)
                    log("🎮 Monde sas chargé sur la console. En attente de stabilisation (2s)...", level: "INFO")

                    // Fallback transfer after 3.5 seconds if SetLocalPlayerAsInitialized is delayed
                    scheduleTransfer(session: session, delay: 3.5, clientAddr: clientAddr, isFallback: true)
                }
            }

            // Case D: RequestChunkRadius (ID 69)
            else if packetId == BedrockProtocol.idRequestChunkRadius {
                let radius = BedrockProtocol.parseRequestChunkRadius(pk) ?? 4
                log("📡 Rayon de chunks console : \(radius). Confirmation envoyée.", level: "DEBUG")
                let radiusPk = BedrockProtocol.buildChunkRadiusUpdated(radius: radius)
                let spawnPk = BedrockProtocol.buildPlayerSpawn()
                let batch = BedrockProtocol.encodeBatch(
                    packets: [radiusPk, spawnPk],
                    compressionAlgo: session.compressionNegotiated ? Int(BedrockProtocol.compressionZlib) : Int(BedrockProtocol.compressionNone)
                )
                let respFrame = EncapsulatedPacket(
                    content: batch,
                    reliability: RakNet.reliabilityReliableOrdered,
                    messageIndex: session.nextMessageIndex(),
                    orderIndex: session.nextOrderIndex()
                )
                sendDatagram(session: session, frames: [respFrame], clientAddr: &clientAddr)
            }

            // Case E: SetLocalPlayerAsInitialized (ID 113)
            else if packetId == BedrockProtocol.idSetLocalPlayerAsInitialized {
                log("🎮 Joueur console apparu dans le sas ! Attente de 2s puis transfert vers le serveur...", level: "SUCCESS")
                scheduleTransfer(session: session, delay: 2.0, clientAddr: clientAddr, isFallback: false)
            }
        }
    }

    private func scheduleTransfer(session: ClientSession, delay: TimeInterval, clientAddr: sockaddr_in, isFallback: Bool = false) {
        guard !session.transferred else { return }

        if isFallback && session.transferScheduled {
            return
        }

        // Cancel previous work item if SetLocalPlayerAsInitialized arrives to reset the 2.0s timer accurately
        session.transferWorkItem?.cancel()
        session.transferScheduled = true

        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            guard !session.transferred else { return }
            session.transferred = true

            var addrCopy = clientAddr
            let playerName = session.playerName
            let destHost = self.resolveHost(self.targetHost)

            let transferPk = BedrockProtocol.buildTransferPacket(address: destHost, port: self.targetPort, reloadWorld: false)
            let transferBatch = BedrockProtocol.encodeBatch(
                packets: [transferPk],
                compressionAlgo: session.compressionNegotiated ? Int(BedrockProtocol.compressionZlib) : Int(BedrockProtocol.compressionNone)
            )
            let respFrame = EncapsulatedPacket(
                content: transferBatch,
                reliability: RakNet.reliabilityReliableOrdered,
                messageIndex: session.nextMessageIndex(),
                orderIndex: session.nextOrderIndex()
            )
            self.sendDatagram(session: session, frames: [respFrame], clientAddr: &addrCopy)

            self.log("✅ Transfert réussi ! \(playerName) est redirigé en direct vers \(destHost):\(self.targetPort)", level: "SUCCESS")
            self.log("🎉 La console communique maintenant en direct avec le serveur externe. Bon jeu !", level: "SUCCESS")

            DispatchQueue.main.async {
                self.onTransferSuccess?(playerName, destHost, self.targetPort)
            }
        }

        session.transferWorkItem = workItem
        DispatchQueue.global().asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func resolveHost(_ host: String) -> String {
        var hints = addrinfo()
        hints.ai_family = AF_INET
        hints.ai_socktype = SOCK_DGRAM
        var res: UnsafeMutablePointer<addrinfo>?
        if getaddrinfo(host, nil, &hints, &res) == 0, let info = res {
            defer { freeaddrinfo(res) }
            var ipBuf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            let addrIn = info.pointee.ai_addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
            var sinAddr = addrIn.sin_addr
            if inet_ntop(AF_INET, &sinAddr, &ipBuf, socklen_t(INET_ADDRSTRLEN)) != nil {
                return String(cString: ipBuf)
            }
        }
        return host
    }

    // MARK: - Network Interfaces & Local IP Discovery
    public struct NetworkInterfaceInfo: Sendable {
        public let name: String
        public let ipAddress: String
        public let broadcastAddress: String?

        public init(name: String, ipAddress: String, broadcastAddress: String?) {
            self.name = name
            self.ipAddress = ipAddress
            self.broadcastAddress = broadcastAddress
        }
    }

    public static func getLocalIPv4Interfaces() -> [NetworkInterfaceInfo] {
        var interfaces: [NetworkInterfaceInfo] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return [] }
        defer { freeifaddrs(ifaddr) }

        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let flags = Int32(ptr.pointee.ifa_flags)
            guard let addrPtr = ptr.pointee.ifa_addr else { continue }
            let family = addrPtr.pointee.sa_family

            // Filter for active non-loopback IPv4 interfaces
            guard (flags & (IFF_UP | IFF_RUNNING)) == (IFF_UP | IFF_RUNNING) else { continue }
            guard (flags & IFF_LOOPBACK) == 0 else { continue }
            guard family == UInt8(AF_INET) else { continue }

            let name = String(cString: ptr.pointee.ifa_name)

            var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            var ip: String?
            if getnameinfo(addrPtr, socklen_t(MemoryLayout<sockaddr_in>.size), &hostBuffer, socklen_t(hostBuffer.count), nil, 0, NI_NUMERICHOST) == 0 {
                ip = String(cString: hostBuffer)
            }

            var bcast: String?
            if let dst = ptr.pointee.ifa_dstaddr, (flags & IFF_BROADCAST) != 0 {
                var bcastBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(dst, socklen_t(MemoryLayout<sockaddr_in>.size), &bcastBuffer, socklen_t(bcastBuffer.count), nil, 0, NI_NUMERICHOST) == 0 {
                    bcast = String(cString: bcastBuffer)
                }
            }

            if let ip = ip, !ip.isEmpty, ip != "127.0.0.1" {
                interfaces.append(NetworkInterfaceInfo(name: name, ipAddress: ip, broadcastAddress: bcast))
            }
        }
        return interfaces
    }

    public static func getPrimaryLocalIP() -> String? {
        let interfaces = getLocalIPv4Interfaces()
        if let wifi = interfaces.first(where: { $0.name == "en0" }) {
            return wifi.ipAddress
        }
        return interfaces.first?.ipAddress
    }
}
