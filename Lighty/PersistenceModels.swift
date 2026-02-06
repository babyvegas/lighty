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
    var secondaryMuscles: [String]
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
        secondaryMuscles: [String],
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
        self.secondaryMuscles = secondaryMuscles
        self.restMinutes = restMinutes
        self.orderIndex = orderIndex
        self.sets = sets
    }
}

@Model
final class WorkoutSetEntity {
    var id: UUID
    var weight: Int
    var reps: Int
    var orderIndex: Int

    init(id: UUID, weight: Int, reps: Int, orderIndex: Int) {
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
    var secondaryMuscles: [String]
    var lastUsedAt: Date

    init(
        id: String,
        name: String,
        muscle: String,
        equipment: String,
        imageURLString: String?,
        mediaURLString: String?,
        primaryMuscle: String,
        secondaryMuscles: [String],
        lastUsedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.muscle = muscle
        self.equipment = equipment
        self.imageURLString = imageURLString
        self.mediaURLString = mediaURLString
        self.primaryMuscle = primaryMuscle
        self.secondaryMuscles = secondaryMuscles
        self.lastUsedAt = lastUsedAt
    }
}
