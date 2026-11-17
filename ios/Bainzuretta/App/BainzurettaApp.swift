import SwiftUI

@main struct BainzurettaApp: App {
    @State private var store = AppStore()
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            RootView().environment(store).tint(Brand.orange)
                .onChange(of:phase) { _, value in if value == .active { store.refreshClock() } }
                .task { await store.sync(silent:true) }
        }
    }
}
