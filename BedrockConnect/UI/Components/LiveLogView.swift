import SwiftUI

public struct LiveLogView: View {
    public let logs: [LogEntry]
    public let onClear: () -> Void

    public init(logs: [LogEntry], onClear: @escaping () -> Void) {
        self.logs = logs
        self.onClear = onClear
    }

    public var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("JOURNAL D'ÉVÉNEMENTS")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppTheme.textSecondary)

                Spacer()

                Button(action: onClear) {
                    Text("Effacer")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppTheme.textMuted)
                }
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        if logs.isEmpty {
                            Text("En attente de démarrage ou de connexion...")
                                .font(.system(size: 12))
                                .foregroundColor(AppTheme.textMuted)
                                .padding(.vertical, 16)
                        } else {
                            ForEach(logs) { entry in
                                HStack(alignment: .top, spacing: 8) {
                                    Text(entry.timeString)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(AppTheme.textMuted)
                                        .padding(.top, 2)

                                    badge(for: entry.level)

                                    Text(entry.message)
                                        .font(.system(size: 12))
                                        .foregroundColor(textColor(for: entry.level))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .id(entry.id)
                            }
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: 180)
                .background(Color(red: 10/255, green: 13/255, blue: 18/255))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AppTheme.cardBorder, lineWidth: 1)
                )
                .onChange(of: logs.count) { _ in
                    if let last = logs.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func badge(for level: String) -> some View {
        let (color, text) = badgeConfig(for: level)
        Text(text)
            .font(.system(size: 8, weight: .black))
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(3)
            .padding(.top, 2)
    }

    private func badgeConfig(for level: String) -> (Color, String) {
        switch level {
        case "SUCCESS": return (AppTheme.emerald, "SUCCÈS")
        case "WARNING": return (AppTheme.amber, "ATTN")
        case "ERROR": return (AppTheme.rose, "ERREUR")
        case "DEBUG": return (AppTheme.textMuted, "DEBUG")
        default: return (AppTheme.sky, "INFO")
        }
    }

    private func textColor(for level: String) -> Color {
        switch level {
        case "SUCCESS": return Color(red: 180/255, green: 250/255, blue: 200/255)
        case "WARNING": return Color(red: 253/255, green: 230/255, blue: 138/255)
        case "ERROR": return Color(red: 254/255, green: 202/255, blue: 202/255)
        case "DEBUG": return AppTheme.textSecondary
        default: return AppTheme.textPrimary
        }
    }
}
