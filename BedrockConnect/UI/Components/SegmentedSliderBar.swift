import SwiftUI

public struct SegmentedSliderBar: View {
    @Binding public var selectedIndex: Int
    public let items: [(icon: String, title: String)]
    @Namespace private var glassTabNamespace

    public init(selectedIndex: Binding<Int>, items: [(icon: String, title: String)]) {
        self._selectedIndex = selectedIndex
        self.items = items
    }

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<items.count, id: \.self) { index in
                let isSelected = selectedIndex == index
                Button(action: {
                    #if canImport(UIKit)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.74)) {
                        selectedIndex = index
                    }
                }) {
                    HStack(spacing: 7) {
                        Image(systemName: items[index].icon)
                            .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                            .foregroundColor(isSelected ? AppTheme.emerald : Color.white.opacity(0.65))

                        Text(items[index].title)
                            .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                            .foregroundColor(isSelected ? .white : Color.white.opacity(0.65))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .contentShape(Rectangle())
                    .background(
                        ZStack {
                            if isSelected {
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.20),
                                                Color.white.opacity(0.08)
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(
                                                LinearGradient(
                                                    colors: [
                                                        Color.white.opacity(0.55),
                                                        Color.white.opacity(0.12)
                                                    ],
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                ),
                                                lineWidth: 0.75
                                            )
                                    )
                                    .shadow(color: Color.black.opacity(0.22), radius: 6, x: 0, y: 2)
                                    .matchedGeometryEffect(id: "appleMusicLiquidPill", in: glassTabNamespace)
                            }
                        }
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: Color.white.opacity(0.12), location: 0.0),
                                    .init(color: Color.white.opacity(0.03), location: 0.4),
                                    .init(color: Color.black.opacity(0.18), location: 1.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .overlay(
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                stops: [
                                    .init(color: Color.white.opacity(0.65), location: 0.0),
                                    .init(color: Color.white.opacity(0.22), location: 0.3),
                                    .init(color: Color.white.opacity(0.05), location: 0.65),
                                    .init(color: Color.white.opacity(0.28), location: 1.0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.75
                        )
                )
        )
        .shadow(color: Color.black.opacity(0.38), radius: 24, x: 0, y: 10)
        .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 2)
    }
}
