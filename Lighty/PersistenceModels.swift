import Foundation
import SwiftData

@Model
final class RoutineEntity {
    @Attribute(.unique) var id: UUID
    var name: String
    var routineDescription: String
    var updatedAt: Date
    @Relationship(deleteRule: .cascade) var exercises: [ExerciseEntity]

    init(id: UUID, name: String, routineDescription: String, updatedAt: Date = .now, exercises: [ExerciseEntity] = []) {
        self.id = id
        self.name = name
        self.routineDescription = routineDescription
        self.updatedAt = updatedAt
        self.exercises = exercises
    }
}

@Model
final class ExerciseEntity {
    var id: UUID
    var name: String
    var notes: String
    var imageURLString: String?
    var mediaURLString: String?
    var primaryMuscle: String
    var secondaryMusclesCSV: String?
    var restMinutes: Double
    var orderIndex: Int
    @Relationship(deleteRule: .cascade) var sets: [WorkoutSetEntity]

    init(
        id: UUID,
        name: String,
        notes: String,
        imageURLString: String?,
        mediaURLString: String?,
        primaryMuscle: String,
        secondaryMusclesCSV: String?,
        restMinutes: Double,
        orderIndex: Int,
        sets: [WorkoutSetEntity] = []
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.imageURLString = imageURLString
        self.mediaURLString = mediaURLString
        self.primaryMuscle = primaryMuscle
        self.secondaryMusclesCSV = secondaryMusclesCSV
        self.restMinutes = restMinutes
        self.orderIndex = orderIndex
        self.sets = sets
    }
}

@Model
final class WorkoutSetEntity {
    var id: UUID
    var weight: Double
    var reps: Int
    var orderIndex: Int

    init(id: UUID, weight: Double, reps: Int, orderIndex: Int) {
        self.id = id
        self.weight = weight
        self.reps = reps
        self.orderIndex = orderIndex
    }
}

@Model
final class RecentExerciseEntity {
    @Attribute(.unique) var id: String
    var name: String
    var muscle: String
    var equipment: String
    var imageURLString: String?
    var mediaURLString: String?
    var primaryMuscle: String
    var secondaryMusclesCSV: String?
    var lastUsedAt: Date

    init(
        id: String,
        name: String,
        muscle: String,
        equipment: String,
        imageURLString: String?,
        mediaURLString: String?,
        primaryMuscle: String,
        secondaryMusclesCSV: String?,
        lastUsedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.muscle = muscle
        self.equipment = equipment
        self.imageURLString = imageURLString
        self.mediaURLString = mediaURLString
        self.primaryMuscle = primaryMuscle
        self.secondaryMusclesCSV = secondaryMusclesCSV
        self.lastUsedAt = lastUsedAt
    }
}

@Model
final class TrainingSessionEntity {
    var id: UUID
    var performedAt: Date
    var title: String
    var exerciseCount: Int
    var durationSeconds: Int?
    var volume: Double?
    var recordsCount: Int?
    var averageHeartRate: Double?
    var exerciseSummariesJSON: String?

    init(
        id: UUID,
        performedAt: Date,
        title: String,
        exerciseCount: Int,
        durationSeconds: Int? = nil,
        volume: Double? = nil,
        recordsCount: Int? = nil,
        averageHeartRate: Double? = nil,
        exerciseSummariesJSON: String? = nil
    ) {
        self.id = id
        self.performedAt = performedAt
        self.title = title
        self.exerciseCount = exerciseCount
        self.durationSeconds = durationSeconds
        self.volume = volume
        self.recordsCount = recordsCount
        self.averageHeartRate = averageHeartRate
        self.exerciseSummariesJSON = exerciseSummariesJSON
    }
}

@Model
final class ExerciseRecordEntity {
    @Attribute(.unique) var exerciseKey: String
    var exerciseName: String
    var attemptsCount: Int
    var bestWeight: Double
    var bestReps: Int
    var bestAt: Date?

    init(
        exerciseKey: String,
        exerciseName: String,
        attemptsCount: Int = 0,
        bestWeight: Double = 0,
        bestReps: Int = 0,
        bestAt: Date? = nil
    ) {
        self.exerciseKey = exerciseKey
        self.exerciseName = exerciseName
        self.attemptsCount = attemptsCount
        self.bestWeight = bestWeight
        self.bestReps = bestReps
        self.bestAt = bestAt
    }
}
