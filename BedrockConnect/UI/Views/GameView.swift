import SwiftUI

public struct GameView: View {
    @ObservedObject public var config: ServerConfigManager
    @State private var showingAddFavoriteSheet = false
    @State private var newFavName = ""

    public init(config: ServerConfigManager) {
        self.config = config
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                partnersSection
                favoritesSection
                connectionSection
                if config.showEventLogs {
                    logsSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 85)
        }
        .sheet(isPresented: $showingAddFavoriteSheet) {
            addFavoriteSheet
        }
    }

    // MARK: - Section A: Partner Servers
    private var partnersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("✦ SERVEURS PARTENAIRES")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppTheme.textSecondary)

            ForEach(config.partners) { partner in
                PartnerServerCardView(
                    server: partner,
                    isSelected: config.selectedPartner?.id == partner.id
                ) {
                    config.selectPartner(partner)
                }
            }
        }
    }

    // MARK: - Section B: Favorites
    @ViewBuilder
    private var favoritesSection: some View {
        if !config.favorites.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("⭐ SERVEURS FAVORIS")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppTheme.textSecondary)

                ForEach(config.favorites) { fav in
                    FavoriteServerCardView(
                        server: fav,
                        isSelected: config.hostInput == fav.host && config.portInput == fav.port,
                        onSelect: {
                            config.clearPartnerSelection()
                            config.hostInput = fav.host
                            config.portInput = fav.port
                        },
                        onDelete: {
                            config.removeFavorite(id: fav.id)
                        }
                    )
                }
            }
        }
    }

    // MARK: - Section C: Connection & Controls Card
    @ViewBuilder
    private var connectionSection: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text("CONNEXION")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppTheme.textSecondary)

                if config.isServerRunning {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(AppTheme.emerald)
                            .frame(width: 8, height: 8)
                        Text("ACTIF (UDP 19132)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(AppTheme.emerald)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppTheme.emerald.opacity(0.15))
                    .cornerRadius(4)
                }

                Spacer()

                if config.isPartnerLocked {
                    HStack(spacing: 4) {
                        Text("🔒 Partenaire")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(AppTheme.sky)

                        Button(action: {
                            config.clearPartnerSelection()
                        }) {
                            Text("✕ Débloquer")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(AppTheme.textSecondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppTheme.cardBorder)
                                .cornerRadius(4)
                        }
                    }
                }
            }

            // Host & Port Fields
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ADRESSE IP / DOMAINE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AppTheme.textMuted)

                    TextField("ex: play.monserveur.fr", text: $config.hostInput)
                        .font(.system(size: 14))
                        .padding(10)
                        .background(Color(red: 13/255, green: 17/255, blue: 23/255))
                        .foregroundColor(config.isPartnerLocked ? AppTheme.textSecondary : AppTheme.textPrimary)
                        .cornerRadius(8)
                        .disabled(config.isPartnerLocked)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("PORT UDP")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AppTheme.textMuted)

                    TextField("19132", value: $config.portInput, format: .number.grouping(.never))
                        .font(.system(size: 14))
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .padding(10)
                        .background(Color(red: 13/255, green: 17/255, blue: 23/255))
                        .foregroundColor(config.isPartnerLocked ? AppTheme.textSecondary : AppTheme.textPrimary)
                        .cornerRadius(8)
                        .disabled(config.isPartnerLocked)
                        .frame(width: 80)
                }
            }

            // Action Buttons Row
            HStack(spacing: 10) {
                Button(action: {
                    #if canImport(UIKit)
                    UINotificationFeedbackGenerator().notificationOccurred(config.isServerRunning ? .warning : .success)
                    #endif
                    config.toggleServer()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: config.isServerRunning ? "stop.fill" : "play.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text(config.isServerRunning ? "ARRÊTER" : "DÉMARRER")
                            .font(.system(size: 14, weight: .black))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(config.isServerRunning ? AppTheme.rose : AppTheme.emerald)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .shadow(color: (config.isServerRunning ? AppTheme.rose : AppTheme.emerald).opacity(0.35), radius: 10, x: 0, y: 3)
                }

                Button(action: {
                    newFavName = config.selectedPartner?.name ?? ""
                    showingAddFavoriteSheet = true
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 13))
                        Text("+ Favori")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(AppTheme.cardBorder)
                    .foregroundColor(AppTheme.amber)
                    .cornerRadius(10)
                }
            }
        }
        .padding(14)
        .liquidGlass(
            cornerRadius: 16,
            strokeGradient: config.isServerRunning ? AppTheme.glassSelectedBorder : AppTheme.glassBorder,
            lineWidth: config.isServerRunning ? 1.8 : 1.0,
            shadowRadius: config.isServerRunning ? 14 : 8,
            shadowY: 4
        )
    }

    // MARK: - Section D: Event Logs
    private var logsSection: some View {
        LiveLogView(logs: config.logs) {
            config.clearLogs()
        }
    }

    // MARK: - Add Favorite Sheet
    @ViewBuilder
    private var addFavoriteSheet: some View {
        VStack(spacing: 16) {
            Text("Ajouter aux Favoris")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Nom du serveur")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.textSecondary)
                TextField("Ex: Mon Serveur Survie", text: $newFavName)
                    .padding(10)
                    .background(AppTheme.cardBorder)
                    .cornerRadius(8)
                    .foregroundColor(.white)
            }

            HStack(spacing: 12) {
                Button("Annuler") {
                    showingAddFavoriteSheet = false
                }
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(AppTheme.cardBorder)
                .foregroundColor(AppTheme.textSecondary)
                .cornerRadius(8)

                Button("Enregistrer") {
                    config.addFavorite(name: newFavName, host: config.hostInput, port: config.portInput)
                    showingAddFavoriteSheet = false
                }
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(AppTheme.emerald)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .padding(20)
        .background(AppTheme.cardBg)
        .preferredColorScheme(.dark)
    }
}
