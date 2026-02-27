import Foundation

// MARK: - Models

enum WorkoutSetType: String, Codable, CaseIterable, Hashable {
    case normal
    case warmup
    case failure

    var shortLabel: String {
        switch self {
        case .normal:
            return ""
        case .warmup:
            return "W"
        case .failure:
            return "F"
        }
    }

    var menuTitle: String {
        switch self {
        case .normal:
            return "Serie Normal"
        case .warmup:
            return "W (Calentamiento)"
        case .failure:
            return "F (Fallo)"
        }
    }
}

struct WorkoutSet: Identifiable, Hashable {
    let id: UUID
    var weight: Double
    var reps: Int
    var type: WorkoutSetType

    init(id: UUID = UUID(), weight: Double = 0, reps: Int = 0, type: WorkoutSetType = .normal) {
        self.id = id
        self.weight = weight
        self.reps = reps
        self.type = type
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
    var durationSeconds: Int
    var volume: Double
    var recordsCount: Int?
    var averageHeartRate: Double?
    var exerciseSummaries: [CompletedTrainingExerciseSummary]

    init(
        id: UUID = UUID(),
        date: Date = .now,
        title: String,
        exerciseCount: Int,
        durationSeconds: Int = 0,
        volume: Double = 0,
        recordsCount: Int? = nil,
        averageHeartRate: Double? = nil,
        exerciseSummaries: [CompletedTrainingExerciseSummary] = []
    ) {
        self.id = id
        self.date = date
        self.title = title
        self.exerciseCount = exerciseCount
        self.durationSeconds = durationSeconds
        self.volume = volume
        self.recordsCount = recordsCount
        self.averageHeartRate = averageHeartRate
        self.exerciseSummaries = exerciseSummaries
    }
}

struct CompletedTrainingExerciseSummary: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var setCount: Int
    var imageURL: URL?

    init(id: UUID = UUID(), name: String, setCount: Int, imageURL: URL? = nil) {
        self.id = id
        self.name = name
        self.setCount = setCount
        self.imageURL = imageURL
    }
}

struct ExercisePersonalRecord: Hashable {
    var date: Date
    var weight: Double
    var reps: Int
}

struct ExerciseRecordSnapshot: Hashable {
    var attemptsCount: Int
    var bestWeight: Double
    var bestReps: Int
    var bestDate: Date?
}

struct CompletedSetRecord: Hashable {
    var exerciseName: String
    var weight: Double
    var reps: Int
    var completedAt: Date
}
