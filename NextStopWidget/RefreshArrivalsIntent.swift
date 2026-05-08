import AppIntents
import WidgetKit
import NextStopKit

/// Tap target for the widget's refresh button. Refetches arrivals for the
/// stops already in the snapshot, writes a new snapshot, and reloads timelines.
@available(iOS 17.0, *)
public struct RefreshArrivalsIntent: AppIntent {
    public static var title: LocalizedStringResource = "Refresh NextStop"
    public static var description: IntentDescription = .init("Update arrival times for the closest stops.")
    public static var isDiscoverable: Bool = false   // hidden from Shortcuts; widget-only

    public init() {}

    public func perform() async throws -> some IntentResult {
        await SnapshotRefresher.refreshFromPrior()
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
