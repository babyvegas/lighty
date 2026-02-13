import SwiftData
import SwiftUI

@main
struct LightyApp: App {
    @StateObject private var store: RoutineStore
    @StateObject private var connectivity = PhoneWatchConnectivityCoordinator()

    init() {
        do {
            let container = try ModelContainer(
                for: RoutineEntity.self,
                ExerciseEntity.self,
                WorkoutSetEntity.self,
                RecentExerciseEntity.self,
                TrainingSessionEntity.self
            )
            _store = StateObject(wrappedValue: RoutineStore(container: container))
        } catch {
            fatalError("Failed to initialize SwiftData container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(connectivity)
        }
    }
}
