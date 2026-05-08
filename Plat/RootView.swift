import SwiftUI
import PlatKit

struct RootView: View {
    @EnvironmentObject private var saved: SavedStopsStore
    @AppStorage("hasSeenOnboarding.v1") private var hasSeenOnboarding = false
    @State private var showOnboarding = false
    @State private var selectedTab = 0
    @State private var savedPath = NavigationPath()

    var body: some View {
        TabView(selection: $selectedTab) {
            SavedStopsView(path: $savedPath)
                .tabItem { Label("Saved", systemImage: "star.fill") }
                .tag(0)
            LineListView()
                .tabItem { Label("Add", systemImage: "plus.circle.fill") }
                .tag(1)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(2)
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView {
                hasSeenOnboarding = true
                showOnboarding = false
            }
        }
        .onAppear {
            if !hasSeenOnboarding { showOnboarding = true }
        }
        .onOpenURL(perform: handleDeepLink)
    }

    /// `plat://group/<encoded-id>` → switch to Saved tab and push the group's
    /// detail (combined feed for grouped, single-stop feed for singletons).
    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "plat", url.host == "group" else { return }
        let raw = url.lastPathComponent
        let id = raw.removingPercentEncoding ?? raw
        guard let group = saved.resolvedGroups.first(where: { $0.id == id }) else { return }

        selectedTab = 0
        savedPath = NavigationPath()
        if group.isGrouped {
            savedPath.append(group)
        } else if let stop = group.stops.first {
            savedPath.append(stop)
        }
    }
}
