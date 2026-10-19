import Foundation

public struct ServerModel: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var host: String
    public var port: UInt16
    public var subName: String
    public var currentPlayers: Int
    public var maxPlayers: Int
    public var isPartner: Bool
    public var isFavorite: Bool
    public var isOnline: Bool?
    public var latencyMs: Int?

    public init(
        id: String = UUID().uuidString,
        name: String,
        host: String,
        port: UInt16 = 19132,
        subName: String = "",
        currentPlayers: Int = 0,
        maxPlayers: Int = 0,
        isPartner: Bool = false,
        isFavorite: Bool = false,
        isOnline: Bool? = nil,
        latencyMs: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.subName = subName
        self.currentPlayers = currentPlayers
        self.maxPlayers = maxPlayers
        self.isPartner = isPartner
        self.isFavorite = isFavorite
        self.isOnline = isOnline
        self.latencyMs = latencyMs
    }

    public static let defaultPartners: [ServerModel] = [
        ServerModel(
            id: "hive",
            name: "The Hive",
            host: "geo.hivebedrock.network",
            port: 19132,
            subName: "Bedwars, Murder Mystery & SkyWars",
            currentPlayers: 6840,
            maxPlayers: 20000,
            isPartner: true
        ),
        ServerModel(
            id: "cubecraft",
            name: "CubeCraft Games",
            host: "play.cubecraft.net",
            port: 19132,
            subName: "EggWars, Lucky Islands & Skyblock",
            currentPlayers: 3850,
            maxPlayers: 10000,
            isPartner: true
        ),
        ServerModel(
            id: "galaxite",
            name: "Galaxite",
            host: "play.galaxite.net",
            port: 19132,
            subName: "Custom Mini-Games, Chronos & Core",
            currentPlayers: 1120,
            maxPlayers: 4000,
            isPartner: true
        ),
        ServerModel(
            id: "lifeboat",
            name: "Lifeboat Network",
            host: "play.lbsg.net",
            port: 19132,
            subName: "Survival Games, Bedwars & Prison",
            currentPlayers: 2730,
            maxPlayers: 8000,
            isPartner: true
        ),
        ServerModel(
            id: "mineville",
            name: "Mineville",
            host: "play.inpvp.net",
            port: 19132,
            subName: "Roleplay, City Life & High School",
            currentPlayers: 1560,
            maxPlayers: 5000,
            isPartner: true
        ),
    ]
}
