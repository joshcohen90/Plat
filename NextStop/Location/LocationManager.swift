import Foundation
import CoreLocation
import Combine
import NextStopKit

@MainActor
public final class LocationManager: NSObject, ObservableObject {
    public static let shared = LocationManager()

    @Published public private(set) var lastLocation: CLLocation?
    @Published public private(set) var authorization: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 100
        manager.pausesLocationUpdatesAutomatically = true
        manager.activityType = .otherNavigation
        // Allow background delivery when "always" auth granted, but only
        // for significant-change events — battery friendly.
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = false
        authorization = manager.authorizationStatus
    }

    public func requestAuthorization() {
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse: manager.requestAlwaysAuthorization()
        default: break
        }
    }

    public func start() {
        manager.startMonitoringSignificantLocationChanges()
        manager.requestLocation()  // immediate one-shot for foreground UI
    }

    public func stop() {
        manager.stopMonitoringSignificantLocationChanges()
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            self.lastLocation = loc
            await RefreshCoordinator.shared.refresh(reason: .locationChanged)
        }
    }

    nonisolated public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in self.authorization = status }
    }

    nonisolated public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Swallow — significant-change errors are common and self-resolving.
    }
}
