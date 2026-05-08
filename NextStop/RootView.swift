import SwiftUI
import NextStopKit

struct RootView: View {
    var body: some View {
        TabView {
            SavedStopsView()
                .tabItem { Label("Saved", systemImage: "star.fill") }
            LineListView()
                .tabItem { Label("Add", systemImage: "plus.circle.fill") }
        }
    }
}
