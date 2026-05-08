import SwiftUI
import PlatKit

struct RootView: View {
    @AppStorage("hasSeenOnboarding.v1") private var hasSeenOnboarding = false
    @State private var showOnboarding = false

    var body: some View {
        TabView {
            SavedStopsView()
                .tabItem { Label("Saved", systemImage: "star.fill") }
            LineListView()
                .tabItem { Label("Add", systemImage: "plus.circle.fill") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
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
    }
}
