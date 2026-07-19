import SwiftUI

@main
struct HandoffApp: App {
    @StateObject private var store: Store
    @StateObject private var careStore: CareCircleStore

    init() {
        let s = Store()
        let c = CareCircleStore()
        c.store = s
        _store = StateObject(wrappedValue: s)
        _careStore = StateObject(wrappedValue: c)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(careStore)
        }
    }
}
