import SwiftUI

struct RootView: View {
    @EnvironmentObject var careStore: CareCircleStore
    @AppStorage("handoff.theme") private var themeRaw = AppTheme.system.rawValue

    var body: some View {
        Group {
            if careStore.circle == nil {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
        .preferredColorScheme(AppTheme(rawValue: themeRaw)?.colorScheme)
        .tint(HandoffColor.lavenderDeep)
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            ConstellationView()
                .tabItem { Label("Circle", systemImage: "circle.grid.3x3.fill") }
            VisitHistoryView()
                .tabItem { Label("Visits", systemImage: "list.bullet.rectangle") }
            DigestView()
                .tabItem { Label("Digest", systemImage: "sparkles") }
        }
    }
}
