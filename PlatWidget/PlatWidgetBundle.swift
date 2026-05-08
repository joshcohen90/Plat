import WidgetKit
import SwiftUI

@main
struct PlatWidgetBundle: WidgetBundle {
    var body: some Widget {
        NearbyStopsWidget()
        ClosestStopWidget()
        LockScreenWidget()
    }
}
