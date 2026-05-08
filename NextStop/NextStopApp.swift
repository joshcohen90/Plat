import SwiftUI
import NextStopKit

@main
struct NextStopApp: App {
    @StateObject private var savedStops = SavedStopsStore.shared
    @StateObject private var locationManager = LocationManager.shared

    init() {
        BackgroundRefresh.register()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(savedStops)
                .environmentObject(locationManager)
                .task {
                    locationManager.requestAuthorization()
                    locationManager.start()
                    await RefreshCoordinator.shared.refresh(reason: .appLaunch)
                    BackgroundRefresh.schedule()
                }
        }
    }
}
