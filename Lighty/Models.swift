import Foundation

// MARK: - Models

struct WorkoutSet: Identifiable, Hashable {
    let id: UUID
    var weight: Int
    var reps: Int

    init(id: UUID = UUID(), weight: Int = 0, reps: Int = 0) {
        self.id = id
        self.weight = weight
        self.reps = reps
    }
}

struct ExerciseEntry: Identifiable, Hashable {
    let id: UUID
    var name: String
    var sets: [WorkoutSet]
    /// 0 means rest timer is off.
    var restMinutes: Int

    init(id: UUID = UUID(), name: String, sets: [WorkoutSet] = [WorkoutSet(), WorkoutSet()], restMinutes: Int = 0) {
        self.id = id
        self.name = name
        self.sets = sets
        self.restMinutes = restMinutes
    }
}

struct Routine: Identifiable, Hashable {
    let id: UUID
    var name: String
    var exercises: [ExerciseEntry]

    init(id: UUID = UUID(), name: String = "New Routine", exercises: [ExerciseEntry] = []) {
        self.id = id
        self.name = name
        self.exercises = exercises
    }
}
