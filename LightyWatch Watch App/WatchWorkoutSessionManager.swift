import Foundation
import SwiftUI
internal import Combine

struct WatchWorkoutSet: Identifiable, Hashable {
    let id: String
    var weight: Double
    var reps: Int
    var isCompleted: Bool
}

struct WatchWorkoutExercise: Identifiable, Hashable {
    let id: String
    var name: String
    var restMinutes: Double
    var sets: [WatchWorkoutSet]
}

@MainActor
final class WatchWorkoutSessionManager: ObservableObject {
    @Published var sessionId: String = ""
    @Published var title: String = "Workout"
    @Published var exercises: [WatchWorkoutExercise] = []

    func applySnapshot(_ payload: [String: Any]) {
        guard let exercisesPayload = payload["exercises"] as? [[String: Any]] else { return }

        sessionId = payload["sessionId"] as? String ?? sessionId
        title = payload["title"] as? String ?? "Workout"

        exercises = exercisesPayload.compactMap { exerciseDict in
            guard let id = exerciseDict["id"] as? String,
                  let name = exerciseDict["name"] as? String else {
                return nil
            }

            let restMinutes: Double = {
                if let value = exerciseDict["restMinutes"] as? Double { return value }
                if let value = exerciseDict["restMinutes"] as? Int { return Double(value) }
                return 0
            }()
            let setsPayload = exerciseDict["sets"] as? [[String: Any]] ?? []
            let sets = setsPayload.compactMap { setDict -> WatchWorkoutSet? in
                guard let setId = setDict["id"] as? String else { return nil }
                let weight: Double = {
                    if let value = setDict["weight"] as? Double { return value }
                    if let value = setDict["weight"] as? Int { return Double(value) }
                    return 0
                }()
                let reps = setDict["reps"] as? Int ?? 0
                let isCompleted = setDict["isCompleted"] as? Bool ?? false
                return WatchWorkoutSet(id: setId, weight: weight, reps: reps, isCompleted: isCompleted)
            }

            return WatchWorkoutExercise(id: id, name: name, restMinutes: restMinutes, sets: sets)
        }
    }

    func toggleSet(exerciseId: String, setId: String) -> Bool {
        guard let exerciseIndex = exercises.firstIndex(where: { $0.id == exerciseId }),
              let setIndex = exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setId }) else {
            return false
        }

        exercises[exerciseIndex].sets[setIndex].isCompleted.toggle()
        return exercises[exerciseIndex].sets[setIndex].isCompleted
    }

    func updateSet(exerciseId: String, setId: String, weight: Double, reps: Int) {
        guard let exerciseIndex = exercises.firstIndex(where: { $0.id == exerciseId }),
              let setIndex = exercises[exerciseIndex].sets.firstIndex(where: { $0.id == setId }) else {
            return
        }
        exercises[exerciseIndex].sets[setIndex].weight = weight
        exercises[exerciseIndex].sets[setIndex].reps = reps
    }

    func reset() {
        sessionId = ""
        title = "Workout"
        exercises = []
    }
}
