import Foundation
import CoreLocation

public enum Closest {
    /// Returns the N closest saved stops to a coordinate, paired with distance in meters.
    public static func nearest(_ stops: [SavedStop], to coord: CLLocationCoordinate2D, limit: Int = 3) -> [(stop: SavedStop, meters: Double)] {
        let here = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        return stops
            .map { (stop: $0, meters: here.distance(from: CLLocation(latitude: $0.latitude, longitude: $0.longitude))) }
            .sorted { $0.meters < $1.meters }
            .prefix(limit)
            .map { $0 }
    }
}
