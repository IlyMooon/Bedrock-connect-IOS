import SwiftUI

public struct ComingSoonView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: 20) {
            Spacer()

            VStack(spacing: 16) {
                Text("🚧")
                    .font(.system(size: 64))

                Text("Bientôt disponible")
                    .font(.system(size: 22, weight: .black))
                    .foregroundColor(AppTheme.textPrimary)

                Text("Cette section est en cours de développement.\nDe nouvelles fonctionnalités inédites arriveront très prochainement !")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Text("EN CONSTRUCTION")
                    .font(.system(size: 11, weight: .heavy))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppTheme.amber.opacity(0.15))
                    .foregroundColor(AppTheme.amber)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppTheme.amber.opacity(0.3), lineWidth: 1)
                    )
            }
            .padding(28)
            .liquidGlass(cornerRadius: 20, strokeGradient: AppTheme.glassBorder, lineWidth: 1.0, shadowRadius: 16, shadowY: 6)
            .padding(.horizontal, 20)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
    }
}
