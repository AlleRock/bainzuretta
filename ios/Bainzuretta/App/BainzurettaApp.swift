import SwiftUI

@main struct BainzurettaApp: App {
    @State private var store = AppStore()
    @Environment(\.scenePhase) private var phase
    private var testDarkMode: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--dark-mode")
        #else
        false
        #endif
    }
    private var testLargeText: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--large-text")
        #else
        false
        #endif
    }
    var body: some Scene {
        WindowGroup {
            RootView().environment(store).tint(Brand.orange)
                .preferredColorScheme(testDarkMode ? .dark : nil)
                .modifier(TestTextSize(enabled:testLargeText))
                .onChange(of:phase) { _, value in if value == .active { store.refreshClock() } }
                .task { await store.sync(silent:true) }
        }
    }
}

private struct TestTextSize: ViewModifier {
    var enabled: Bool
    @ViewBuilder func body(content: Content) -> some View {
        if enabled { content.dynamicTypeSize(.accessibility3) } else { content }
    }
}
