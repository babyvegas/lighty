import Foundation

// MARK: - Models

struct WorkoutSet: Identifiable, Hashable {
    let id: UUID
    var weight: Double
    var reps: Int

    init(id: UUID = UUID(), weight: Double = 0, reps: Int = 0) {
        self.id = id
        self.weight = weight
        self.reps = reps
    }
}

struct ExerciseEntry: Identifiable, Hashable {
    let id: UUID
    var name: String
    var notes: String
    var imageURL: URL?
    var mediaURL: URL?
    var primaryMuscle: String
    var secondaryMuscles: [String]
    var sets: [WorkoutSet]
    /// 0 means rest timer is off. Values are in minutes, with 0.5 increments.
    var restMinutes: Double

    init(
        id: UUID = UUID(),
        name: String,
        notes: String = "",
        imageURL: URL? = nil,
        mediaURL: URL? = nil,
        primaryMuscle: String = "Unknown",
        secondaryMuscles: [String] = [],
        sets: [WorkoutSet] = [WorkoutSet(), WorkoutSet()],
        restMinutes: Double = 0
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.imageURL = imageURL
        self.mediaURL = mediaURL
        self.primaryMuscle = primaryMuscle
        self.secondaryMuscles = secondaryMuscles
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

struct ExerciseCatalogItem: Identifiable, Hashable {
    let id: String
    var name: String
    var muscle: String
    var equipment: String
    var imageURL: URL?
    var mediaURL: URL?
    var primaryMuscle: String
    var secondaryMuscles: [String]
}

struct CompletedTraining: Identifiable, Hashable {
    let id: UUID
    var date: Date
    var title: String
    var exerciseCount: Int

    init(id: UUID = UUID(), date: Date = .now, title: String, exerciseCount: Int) {
        self.id = id
        self.date = date
        self.title = title
        self.exerciseCount = exerciseCount
    }
}
