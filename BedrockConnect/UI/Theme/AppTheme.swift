import SwiftUI

public struct AppTheme {
    public static let background = Color(red: 13/255, green: 17/255, blue: 23/255)
    public static let cardBg = Color(red: 22/255, green: 27/255, blue: 34/255)
    public static let cardBorder = Color(red: 33/255, green: 38/255, blue: 45/255)
    public static let cardSelectedBorder = Color(red: 46/255, green: 204/255, blue: 113/255)

    public static let emerald = Color(red: 46/255, green: 204/255, blue: 113/255)
    public static let emeraldGlow = Color(red: 46/255, green: 204/255, blue: 113/255).opacity(0.3)
    public static let emeraldDark = Color(red: 31/255, green: 139/255, blue: 76/255)

    public static let sky = Color(red: 56/255, green: 189/255, blue: 248/255)
    public static let amber = Color(red: 251/255, green: 191/255, blue: 36/255)
    public static let rose = Color(red: 244/255, green: 63/255, blue: 94/255)

    public static let textPrimary = Color.white
    public static let textSecondary = Color(red: 148/255, green: 163/255, blue: 184/255)
    public static let textMuted = Color(red: 100/255, green: 116/255, blue: 139/255)

    // MARK: - Liquid Glass Styles
    public static let glassBorder = LinearGradient(
        colors: [
            Color.white.opacity(0.35),
            Color.white.opacity(0.12),
            Color.white.opacity(0.04),
            Color.white.opacity(0.18)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    public static let glassSelectedBorder = LinearGradient(
        colors: [
            emerald.opacity(0.9),
            emerald.opacity(0.45),
            Color.white.opacity(0.25)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    public static let glassFill = Color(red: 22/255, green: 28/255, blue: 40/255).opacity(0.65)
    public static let glassActivePill = Color(red: 32/255, green: 42/255, blue: 58/255).opacity(0.85)

    public static let glassHighlight = LinearGradient(
        colors: [
            Color.white.opacity(0.16),
            Color.white.opacity(0.03),
            Color.clear
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - Liquid Glass View Modifier
public struct LiquidGlassModifier: ViewModifier {
    public var cornerRadius: CGFloat
    public var strokeGradient: LinearGradient
    public var lineWidth: CGFloat
    public var shadowColor: Color
    public var shadowRadius: CGFloat
    public var shadowY: CGFloat

    public init(
        cornerRadius: CGFloat = 16,
        strokeGradient: LinearGradient = AppTheme.glassBorder,
        lineWidth: CGFloat = 1.0,
        shadowColor: Color = Color.black.opacity(0.4),
        shadowRadius: CGFloat = 14,
        shadowY: CGFloat = 6
    ) {
        self.cornerRadius = cornerRadius
        self.strokeGradient = strokeGradient
        self.lineWidth = lineWidth
        self.shadowColor = shadowColor
        self.shadowRadius = shadowRadius
        self.shadowY = shadowY
    }

    public func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 25/255, green: 32/255, blue: 46/255).opacity(0.65),
                                        Color(red: 16/255, green: 20/255, blue: 30/255).opacity(0.75)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .strokeBorder(strokeGradient, lineWidth: lineWidth)
                    )
            )
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowY)
    }
}

public extension View {
    func liquidGlass(
        cornerRadius: CGFloat = 16,
        strokeGradient: LinearGradient = AppTheme.glassBorder,
        lineWidth: CGFloat = 1.0,
        shadowColor: Color = Color.black.opacity(0.4),
        shadowRadius: CGFloat = 14,
        shadowY: CGFloat = 6
    ) -> some View {
        self.modifier(LiquidGlassModifier(
            cornerRadius: cornerRadius,
            strokeGradient: strokeGradient,
            lineWidth: lineWidth,
            shadowColor: shadowColor,
            shadowRadius: shadowRadius,
            shadowY: shadowY
        ))
    }
}
