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
    var notes: String
    var sets: [WorkoutSet]
    /// 0 means rest timer is off. Values are in minutes, with 0.5 increments.
    var restMinutes: Double

    init(
        id: UUID = UUID(),
        name: String,
        notes: String = "",
        sets: [WorkoutSet] = [WorkoutSet(), WorkoutSet()],
        restMinutes: Double = 0
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.sets = sets
        self.restMinutes = restMinutes
    }
}

struct Routine: Identifiable, Hashable {
    let id: UUID
    var name: String
    var description: String
    var exercises: [ExerciseEntry]

    init(
        id: UUID = UUID(),
        name: String = "New Routine",
        description: String = "",
        exercises: [ExerciseEntry] = []
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.exercises = exercises
    }
}
