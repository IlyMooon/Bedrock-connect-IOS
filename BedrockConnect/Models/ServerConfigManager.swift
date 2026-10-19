import Foundation
import Combine

@MainActor
public final class ServerConfigManager: ObservableObject {
    @Published public var partners: [ServerModel] = ServerModel.defaultPartners
    @Published public var favorites: [ServerModel] = []
    @Published public var selectedPartner: ServerModel?

    @Published public var hostInput: String = "geo.hivebedrock.network"
    @Published public var portInput: UInt16 = 19132
    @Published public var isPartnerLocked: Bool = false

    @Published public var isServerRunning: Bool = false
    @Published public var localIp: String = "0.0.0.0"
    @Published public var logs: [LogEntry] = []
    @Published public var activePlayerCount: Int = 0
    @Published public var lastTransferredPlayer: String?
    @Published public var showEventLogs: Bool {
        didSet {
            UserDefaults.standard.set(showEventLogs, forKey: "show_event_logs")
        }
    }

    private var server: BedrockTransferServer?
    private let favoritesKey = "bedrock_connect_favorites"

    public init() {
        self.showEventLogs = UserDefaults.standard.bool(forKey: "show_event_logs")
        self.localIp = BedrockTransferServer.getPrimaryLocalIP() ?? "0.0.0.0"
        loadFavorites()
        // Auto-select first partner by default
        if let first = partners.first {
            selectPartner(first)
        }
        startBackgroundPings()
    }

    public func loadFavorites() {
        if let data = UserDefaults.standard.data(forKey: favoritesKey),
           let list = try? JSONDecoder().decode([ServerModel].self, from: data) {
            self.favorites = list
        }
    }

    public func saveFavorites() {
        if let data = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(data, forKey: favoritesKey)
        }
    }

    public func addFavorite(name: String, host: String, port: UInt16, subName: String = "") {
        guard favorites.count < 5 else { return }
        let newFav = ServerModel(
            name: name.isEmpty ? host : name,
            host: host,
            port: port,
            subName: subName,
            isFavorite: true
        )
        favorites.append(newFav)
        saveFavorites()
        addLog("Serveur '\(newFav.name)' ajouté aux favoris.", level: "INFO")
    }

    public func removeFavorite(id: String) {
        favorites.removeAll { $0.id == id }
        saveFavorites()
    }

    public func selectPartner(_ partner: ServerModel) {
        selectedPartner = partner
        hostInput = partner.host
        portInput = partner.port
        isPartnerLocked = true
    }

    public func clearPartnerSelection() {
        selectedPartner = nil
        isPartnerLocked = false
    }

    public func toggleServer() {
        if isServerRunning {
            stopServer()
        } else {
            startServer()
        }
    }

    public func startServer() {
        guard !isServerRunning else { return }
        self.localIp = BedrockTransferServer.getPrimaryLocalIP() ?? "0.0.0.0"

        let sName = selectedPartner?.name ?? (hostInput.isEmpty ? "Bedrock DirectConnect" : hostInput)
        let sSub = selectedPartner?.subName ?? "Cliquez pour rejoindre"

        let srv = BedrockTransferServer(
            bindIp: "0.0.0.0",
            bindPort: 19132,
            targetHost: hostInput,
            targetPort: portInput,
            serverName: sName,
            subName: sSub
        )

        srv.onLog = { [weak self] msg, lvl in
            Task { @MainActor in
                self?.addLog(msg, level: lvl)
            }
        }

        srv.onPlayerDetected = { [weak self] pName, _ in
            Task { @MainActor in
                self?.activePlayerCount += 1
            }
        }

        srv.onTransferSuccess = { [weak self] pName, _, _ in
            Task { @MainActor in
                self?.lastTransferredPlayer = pName
            }
        }

        self.server = srv
        srv.start()
        self.isServerRunning = true
    }

    public func stopServer() {
        guard isServerRunning else { return }
        server?.stop()
        server = nil
        isServerRunning = false
        activePlayerCount = 0
    }

    public func addLog(_ message: String, level: String = "INFO") {
        let entry = LogEntry(message: message, level: level)
        logs.append(entry)
        if logs.count > 200 {
            logs.removeFirst(logs.count - 200)
        }
    }

    public func clearLogs() {
        logs.removeAll()
    }

    public func startBackgroundPings() {
        Task {
            for (idx, partner) in partners.enumerated() {
                let res = await BedrockQuery.pingBedrockServer(host: partner.host, port: partner.port, timeout: 2.0)
                if res.online {
                    self.partners[idx].isOnline = true
                    self.partners[idx].latencyMs = res.latencyMs
                    self.partners[idx].currentPlayers = res.currentPlayers
                    self.partners[idx].maxPlayers = res.maxPlayers
                } else {
                    self.partners[idx].isOnline = false
                }
            }
        }
    }
}
