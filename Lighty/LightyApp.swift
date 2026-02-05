import SwiftUI

@main
struct LightyApp: App {
    @StateObject private var store = RoutineStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
