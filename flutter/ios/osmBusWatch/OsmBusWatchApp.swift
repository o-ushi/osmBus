import SwiftUI

@main
struct OsmBusWatchApp: App {
    init() {
        WatchRideStore.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            WatchRideView(store: WatchRideStore.shared)
        }
    }
}
