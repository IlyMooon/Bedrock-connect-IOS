import SwiftUI

public struct PartnerServerCardView: View {
    public let server: ServerModel
    public let isSelected: Bool
    public let action: () -> Void

    public init(server: ServerModel, isSelected: Bool, action: @escaping () -> Void) {
        self.server = server
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button(action: {
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            #endif
            action()
        }) {
            HStack(spacing: 12) {
                // Server Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected ? AppTheme.emeraldGlow : AppTheme.cardBorder.opacity(0.5))
                        .frame(width: 44, height: 44)

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "cube.fill")
                        .font(.system(size: 20))
                        .foregroundColor(isSelected ? AppTheme.emerald : AppTheme.sky)
                }

                // Info
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(server.name)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(AppTheme.textPrimary)

                        if isSelected {
                            Text("SÉLECTIONNÉ")
                                .font(.system(size: 9, weight: .heavy))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppTheme.emerald.opacity(0.2))
                                .foregroundColor(AppTheme.emerald)
                                .cornerRadius(4)
                        }
                    }

                    Text(server.subName)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                // Stats: Players & Latency
                VStack(alignment: .trailing, spacing: 4) {
                    if let lat = server.latencyMs {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(lat < 80 ? AppTheme.emerald : AppTheme.amber)
                                .frame(width: 6, height: 6)
                            Text("\(lat) ms")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(lat < 80 ? AppTheme.emerald : AppTheme.amber)
                        }
                    }

                    HStack(spacing: 3) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 10))
                        Text(formatPlayers(server.currentPlayers))
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(AppTheme.textMuted)
                }
            }
            .padding(12)
            .liquidGlass(
                cornerRadius: 14,
                strokeGradient: isSelected ? AppTheme.glassSelectedBorder : AppTheme.glassBorder,
                lineWidth: isSelected ? 1.5 : 1.0,
                shadowRadius: isSelected ? 8 : 4,
                shadowY: 2
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func formatPlayers(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fk", Double(count) / 1000.0)
        }
        return "\(count)"
    }
}
