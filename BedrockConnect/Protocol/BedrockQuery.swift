import Foundation

public struct ServerPingResult: Sendable {
    public var online: Bool
    public var host: String
    public var port: UInt16
    public var latencyMs: Int
    public var serverName: String
    public var cleanServerName: String
    public var protocolVersion: String
    public var versionName: String
    public var currentPlayers: Int
    public var maxPlayers: Int
    public var subName: String
    public var cleanSubName: String
    public var gameMode: String
    public var rawMotd: String
    public var error: String?

    public init(
        online: Bool,
        host: String,
        port: UInt16,
        latencyMs: Int = 0,
        serverName: String = "",
        cleanServerName: String = "",
        protocolVersion: String = "",
        versionName: String = "",
        currentPlayers: Int = 0,
        maxPlayers: Int = 0,
        subName: String = "",
        cleanSubName: String = "",
        gameMode: String = "Survival",
        rawMotd: String = "",
        error: String? = nil
    ) {
        self.online = online
        self.host = host
        self.port = port
        self.latencyMs = latencyMs
        self.serverName = serverName
        self.cleanServerName = cleanServerName
        self.protocolVersion = protocolVersion
        self.versionName = versionName
        self.currentPlayers = currentPlayers
        self.maxPlayers = maxPlayers
        self.subName = subName
        self.cleanSubName = cleanSubName
        self.gameMode = gameMode
        self.rawMotd = rawMotd
        self.error = error
    }
}

public struct BedrockQuery {
    public static func cleanMinecraftText(_ text: String) -> String {
        return text.replacingOccurrences(of: #"[§&][0-9a-fk-or]"#, with: "", options: .regularExpression)
    }

    public static func pingBedrockServer(host: String, port: UInt16 = 19132, timeout: TimeInterval = 2.5) async -> ServerPingResult {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let res = pingSync(host: host, port: port, timeout: timeout)
                continuation.resume(returning: res)
            }
        }
    }

    public static func pingSync(host: String, port: UInt16 = 19132, timeout: TimeInterval = 2.5) -> ServerPingResult {
        let sock = socket(AF_INET, SOCK_DGRAM, 0)
        guard sock >= 0 else {
            return ServerPingResult(online: false, host: host, port: port, error: "Échec création socket UDP")
        }
        defer { close(sock) }

        var tv = timeval(tv_sec: Int(timeout), tv_usec: Int32((timeout - Double(Int(timeout))) * 1_000_000))
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        var hints = addrinfo()
        hints.ai_family = AF_INET
        hints.ai_socktype = SOCK_DGRAM

        var servinfo: UnsafeMutablePointer<addrinfo>?
        let portStr = String(port)
        guard getaddrinfo(host, portStr, &hints, &servinfo) == 0, let info = servinfo else {
            return ServerPingResult(online: false, host: host, port: port, error: "Résolution DNS échouée")
        }
        defer { freeaddrinfo(servinfo) }

        var pingData = Data()
        pingData.append(RakNet.idUnconnectedPing)
        let clientTime = UInt64(Date().timeIntervalSince1970 * 1000)
        var ct = clientTime.bigEndian
        withUnsafeBytes(of: &ct) { pingData.append(contentsOf: $0) }
        pingData.append(RakNet.magic)
        let guid: Int64 = 12345678
        var g = guid.bigEndian
        withUnsafeBytes(of: &g) { pingData.append(contentsOf: $0) }

        let startTime = Date()
        let sent = pingData.withUnsafeBytes { raw in
            sendto(sock, raw.baseAddress, raw.count, 0, info.pointee.ai_addr, info.pointee.ai_addrlen)
        }
        guard sent > 0 else {
            return ServerPingResult(online: false, host: host, port: port, error: "Échec d'envoi UDP")
        }

        var buffer = [UInt8](repeating: 0, count: 4096)
        let bytesRead = recvfrom(sock, &buffer, buffer.count, 0, nil, nil)
        let latencyMs = Int(Date().timeIntervalSince(startTime) * 1000)

        guard bytesRead >= 35 else {
            return ServerPingResult(online: false, host: host, port: port, error: "Timeout ou réponse vide")
        }

        let respData = Data(buffer[0..<bytesRead])
        guard let parsed = RakNet.parseUnconnectedPong(respData) else {
            return ServerPingResult(online: false, host: host, port: port, error: "Réponse UnconnectedPong invalide")
        }

        let motdStr = parsed.motd
        let tokens = motdStr.components(separatedBy: ";")

        let sName = tokens.count > 1 ? tokens[1] : host
        let pVersion = tokens.count > 2 ? tokens[2] : "Unknown"
        let vName = tokens.count > 3 ? tokens[3] : "Unknown"
        let cPlayers = (tokens.count > 4 ? Int(tokens[4]) : nil) ?? 0
        let mPlayers = (tokens.count > 5 ? Int(tokens[5]) : nil) ?? 0
        let sub = tokens.count > 7 ? tokens[7] : ""
        let mode = tokens.count > 8 ? tokens[8] : "Survival"

        return ServerPingResult(
            online: true,
            host: host,
            port: port,
            latencyMs: latencyMs,
            serverName: sName,
            cleanServerName: cleanMinecraftText(sName),
            protocolVersion: pVersion,
            versionName: vName,
            currentPlayers: cPlayers,
            maxPlayers: mPlayers,
            subName: sub,
            cleanSubName: cleanMinecraftText(sub),
            gameMode: mode,
            rawMotd: motdStr,
            error: nil
        )
    }
}
