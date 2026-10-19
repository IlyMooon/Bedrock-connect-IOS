import SwiftUI

public struct MainContainerView: View {
    @StateObject private var config = ServerConfigManager()
    @State private var selectedTab: Int = 0

    public init() {}

    private let tabItems: [(icon: String, title: String)] = [
        ("gamecontroller.fill", "Jeu"),
        ("wrench.and.screwdriver.fill", "Bientôt..."),
        ("info.circle.fill", "Infos")
    ]

    public var body: some View {
        Group {
            if selectedTab == 0 {
                GameView(config: config)
            } else if selectedTab == 1 {
                ComingSoonView()
            } else {
                InfosView(config: config)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            SegmentedSliderBar(
                selectedIndex: $selectedTab,
                items: tabItems
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .preferredColorScheme(.dark)
    }
}
