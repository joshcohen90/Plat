import WidgetKit
import SwiftUI

@main
struct NextStopWidgetBundle: WidgetBundle {
    var body: some Widget {
        NearbyStopsWidget()
        LockScreenWidget()
    }
}
