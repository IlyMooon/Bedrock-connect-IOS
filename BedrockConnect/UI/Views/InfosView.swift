import SwiftUI

public struct InfosView: View {
    @ObservedObject public var config: ServerConfigManager
    @State private var selectedPage: Int = 0
    @State private var selectedConsoleTab: Int = 0

    public init(config: ServerConfigManager) {
        self.config = config
    }

    public var body: some View {
        VStack(spacing: 0) {
            if selectedPage == 0 {
                menuPage
            } else if selectedPage == 1 {
                guidePage
            } else if selectedPage == 2 {
                troubleshootPage
            } else if selectedPage == 3 {
                aboutPage
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
    }

    // MARK: - Subpage Header
    private func subHeader(title: String) -> some View {
        HStack(spacing: 12) {
            Button(action: {
                withAnimation { selectedPage = 0 }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                    Text("Retour")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(AppTheme.emerald)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AppTheme.cardBg)
                .cornerRadius(8)
            }

            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Color(red: 16/255, green: 21/255, blue: 29/255).opacity(0.85)
                .background(.ultraThinMaterial)
        )
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.white.opacity(0.12)),
            alignment: .bottom
        )
    }

    // MARK: - Menu Hub Page
    private var menuPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Centre d'Aide & Réglages")
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(AppTheme.textPrimary)

                    Text("Options d'affichage, guides console et dépannage.")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.textSecondary)
                }
                .padding(.top, 8)

                // Options Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("OPTIONS D'AFFICHAGE")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AppTheme.textSecondary)

                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(AppTheme.emerald.opacity(0.15))
                                .frame(width: 44, height: 44)
                            Image(systemName: "terminal.fill")
                                .font(.system(size: 18))
                                .foregroundColor(AppTheme.emerald)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Journal d'événements")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(AppTheme.textPrimary)

                            Text("Afficher les logs en direct sur la page Jeu")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.textSecondary)
                        }

                        Spacer()

                        Toggle("", isOn: $config.showEventLogs)
                            .labelsHidden()
                            .tint(AppTheme.emerald)
                    }
                    .padding(14)
                    .liquidGlass(cornerRadius: 14, strokeGradient: AppTheme.glassBorder, lineWidth: 1.0, shadowRadius: 8, shadowY: 3)
                }

                // Guides Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("DOCUMENTATION & GUIDES")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AppTheme.textSecondary)

                    VStack(spacing: 12) {
                        menuCard(
                            icon: "gamecontroller.fill",
                            title: "Guide de Connexion Console",
                            subtitle: "PlayStation, Xbox, Switch, Mobile",
                            accentColor: AppTheme.sky
                        ) {
                            withAnimation { selectedPage = 1 }
                        }

                        menuCard(
                            icon: "wrench.and.screwdriver.fill",
                            title: "Dépannage & Solutions",
                            subtitle: "Que faire si le serveur n'apparaît pas",
                            accentColor: AppTheme.amber
                        ) {
                            withAnimation { selectedPage = 2 }
                        }

                        menuCard(
                            icon: "info.circle.fill",
                            title: "À Propos & Redirection",
                            subtitle: "Fonctionnement 100% Standalone",
                            accentColor: AppTheme.emerald
                        ) {
                            withAnimation { selectedPage = 3 }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 85)
        }
    }

    private func menuCard(icon: String, title: String, subtitle: String, accentColor: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(accentColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(accentColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(AppTheme.textPrimary)

                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.textMuted)
            }
            .padding(14)
            .liquidGlass(cornerRadius: 14, strokeGradient: AppTheme.glassBorder, lineWidth: 1.0, shadowRadius: 8, shadowY: 3)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Guide Page
    private var guidePage: some View {
        VStack(spacing: 0) {
            subHeader(title: "Guide Console")

            // Segmented console picker
            Picker("Console", selection: $selectedConsoleTab) {
                Text("PlayStation").tag(0)
                Text("Xbox").tag(1)
                Text("Switch").tag(2)
                Text("Mobile").tag(3)
            }
            .pickerStyle(.segmented)
            .padding(12)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if selectedConsoleTab == 0 {
                        guideContent(
                            title: "PlayStation 4 & PlayStation 5",
                            steps: [
                                "Assurez-vous que votre iPhone et votre console sont sur le même réseau Wi-Fi local.",
                                "Dans l'onglet 'Jeu', choisissez votre serveur et cliquez sur 'DÉMARRER LA REDIRECTION'.",
                                "Allumez votre PlayStation et lancez Minecraft Bedrock Edition.",
                                "Dans le menu principal, cliquez sur 'Jouer' puis allez sur l'onglet 'Amis'.",
                                "Faites défiler tout en bas jusqu'à la section 'Parties en réseau local (LAN Games)'.",
                                "Cliquez sur 'Bedrock DirectConnect' pour rejoindre !",
                                "Une fois transféré dans le serveur distant, vous pouvez fermer cette application."
                            ]
                        )
                    } else if selectedConsoleTab == 1 {
                        guideContent(
                            title: "Xbox One & Xbox Series X|S",
                            steps: [
                                "Connectez votre Xbox et votre iPhone sur le même réseau local ou Wi-Fi.",
                                "Démarrez la redirection dans l'application avec le bouton vert.",
                                "Ouvrez Minecraft sur votre Xbox.",
                                "Rendez-vous dans Jouer > Amis > Parties en réseau local.",
                                "Sélectionnez le serveur local pour être redirigé automatiquement."
                            ]
                        )
                    } else if selectedConsoleTab == 2 {
                        guideContent(
                            title: "Nintendo Switch",
                            steps: [
                                "Connectez votre Switch sur le même point d'accès Wi-Fi que l'iPhone.",
                                "Assurez-vous d'être connecté à votre compte Microsoft dans Minecraft Switch.",
                                "Démarrez la redirection dans l'application.",
                                "Allez dans Jouer > Onglet Amis > Parties en réseau local.",
                                "Cliquez sur le serveur diffusé pour rejoindre votre partie."
                            ]
                        )
                    } else {
                        guideContent(
                            title: "iOS & Android",
                            steps: [
                                "Pour jouer depuis un autre téléphone ou tablette : connectez les deux appareils au même Wi-Fi.",
                                "Lancez la redirection sur cet iPhone.",
                                "Sur l'autre appareil, ouvrez Minecraft > Onglet Amis > Parties LAN.",
                                "Le serveur apparaîtra instantanément."
                            ]
                        )
                    }

                    // Standalone info box
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16))
                            .foregroundColor(AppTheme.emerald)
                            .padding(.top, 2)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Fonctionnement Standalone Déconnectable")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(AppTheme.emerald)

                            Text("Contrairement aux proxys classiques, Bedrock DirectConnect envoie un ordre natif de transfert (TransferPacket ID 85). Dès que vous êtes transféré, l'iPhone ne relaye plus aucun paquet : vous pouvez verrouiller votre iPhone ou fermer l'appli sans interruption de jeu !")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                    .padding(12)
                    .background(AppTheme.emerald.opacity(0.12))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(AppTheme.emerald.opacity(0.3), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 85)
            }
        }
    }

    private func guideContent(title: String, steps: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(AppTheme.sky)

            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(index + 1)")
                        .font(.system(size: 11, weight: .black))
                        .frame(width: 22, height: 22)
                        .background(AppTheme.cardBorder)
                        .foregroundColor(AppTheme.emerald)
                        .cornerRadius(6)

                    Text(step)
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(14)
        .liquidGlass(cornerRadius: 14, strokeGradient: AppTheme.glassBorder, lineWidth: 1.0, shadowRadius: 8, shadowY: 3)
    }

    // MARK: - Troubleshoot Page
    private var troubleshootPage: some View {
        VStack(spacing: 0) {
            subHeader(title: "Dépannage & Solutions")

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    troubleshootCard(
                        title: "1. Le serveur n'apparaît pas dans l'onglet Amis",
                        solution: "• Vérifiez l'autorisation 'Réseau local' d'iOS dans Réglages > BedrockConnect.\n• Vérifiez que votre console et votre iPhone sont sur le même réseau Wi-Fi (attention aux réseaux 2.4 GHz vs 5 GHz isolés par la box internet).\n• Désactivez l'option 'Isolation AP' ou 'Isolation client' sur votre routeur Wi-Fi."
                    )

                    troubleshootCard(
                        title: "2. Blocage sur 'Recherche du serveur...'",
                        solution: "• Redémarrez la redirection dans l'application avec le bouton Arrêter / Démarrer.\n• Assurez-vous qu'aucun autre serveur local n'écoute sur le port UDP 19132."
                    )

                    troubleshootCard(
                        title: "3. 'Impossible de se connecter au monde'",
                        solution: "• Testez le serveur distant avec le bouton de statut pour vérifier qu'il est bien en ligne.\n• Vérifiez que le port du serveur cible est correct (ex: 19132 pour Bedrock)."
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 85)
            }
        }
    }

    private func troubleshootCard(title: String, solution: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(AppTheme.amber)

            Text(solution)
                .font(.system(size: 13))
                .foregroundColor(AppTheme.textSecondary)
                .lineSpacing(3)
        }
        .padding(14)
        .liquidGlass(cornerRadius: 14, strokeGradient: AppTheme.glassBorder, lineWidth: 1.0, shadowRadius: 8, shadowY: 3)
    }

    // MARK: - About Page
    private var aboutPage: some View {
        VStack(spacing: 0) {
            subHeader(title: "À Propos")

            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 8) {
                        Text("🎮")
                            .font(.system(size: 48))

                        Text("Bedrock DirectConnect iOS")
                            .font(.system(size: 18, weight: .black))
                            .foregroundColor(AppTheme.textPrimary)

                        Text("Version 2.0 Native iOS")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(AppTheme.emerald)
                    }
                    .padding(.vertical, 10)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Architecture Standalone Native")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(AppTheme.sky)

                        Text("Cette application a été spécialement conçue pour iOS en Swift 6 natif. Elle n'utilise aucun serveur proxy distant ni intermédiaire cloud : tout s'exécute directement sur votre iPhone.")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.textSecondary)

                        Divider().background(AppTheme.cardBorder)

                        Text("Protocole TransferPacket (ID 85)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(AppTheme.sky)

                        Text("En exploitant le protocole officiel de redirection de Minecraft Bedrock, votre console établit une connexion directe avec l'adresse IP du serveur cible. La batterie de votre iPhone est ainsi préservée !")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .padding(16)
                    .liquidGlass(cornerRadius: 16, strokeGradient: AppTheme.glassBorder, lineWidth: 1.0, shadowRadius: 10, shadowY: 4)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 85)
            }
        }
    }
}
