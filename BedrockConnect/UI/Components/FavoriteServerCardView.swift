import SwiftUI

public struct FavoriteServerCardView: View {
    public let server: ServerModel
    public let isSelected: Bool
    public let onSelect: () -> Void
    public let onDelete: () -> Void

    public init(server: ServerModel, isSelected: Bool, onSelect: @escaping () -> Void, onDelete: @escaping () -> Void) {
        self.server = server
        self.isSelected = isSelected
        self.onSelect = onSelect
        self.onDelete = onDelete
    }

    public var body: some View {
        HStack(spacing: 10) {
            Button(action: {
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
                onSelect()
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 16))
                        .foregroundColor(AppTheme.amber)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(server.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)

                        Text(verbatim: "\(server.host):\(server.port)")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(AppTheme.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer()
                }
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: {
                #if canImport(UIKit)
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                #endif
                onDelete()
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.rose.opacity(0.8))
                    .padding(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(10)
        .liquidGlass(
            cornerRadius: 12,
            strokeGradient: isSelected ? AppTheme.glassSelectedBorder : AppTheme.glassBorder,
            lineWidth: isSelected ? 1.5 : 1.0,
            shadowRadius: isSelected ? 8 : 4,
            shadowY: 2
        )
    }
}
