import Foundation
import SwiftData
import SwiftUI
internal import Combine

// MARK: - Store

final class RoutineStore: ObservableObject {
    @Published private(set) var routines: [Routine] = []
    @Published private(set) var recentExercises: [ExerciseCatalogItem] = []

    private let container: ModelContainer
    private let context: ModelContext

    convenience init() {
        do {
            let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try ModelContainer(
                for: RoutineEntity.self,
                ExerciseEntity.self,
                WorkoutSetEntity.self,
                RecentExerciseEntity.self,
                configurations: configuration
            )
            self.init(container: container)
        } catch {
            fatalError("Failed to initialize in-memory SwiftData container: \(error)")
        }
    }

    init(container: ModelContainer) {
        self.container = container
        self.context = ModelContext(container)
        loadFromPersistence()
    }

    func save(_ routine: Routine) {
        if let index = routines.firstIndex(where: { $0.id == routine.id }) {
            routines[index] = routine
        } else {
            routines.append(routine)
        }

        persistRoutine(routine)
    }

    func routine(with id: Routine.ID) -> Routine? {
        routines.first { $0.id == id }
    }

    func delete(_ routine: Routine) {
        routines.removeAll { $0.id == routine.id }

        if let entity = fetchRoutineEntity(id: routine.id) {
            context.delete(entity)
            saveContext()
        }
    }

    func duplicate(_ routine: Routine) {
        let copy = Routine(
            name: "Copy of \(routine.name)",
            description: routine.description,
            exercises: routine.exercises
        )
        save(copy)
    }

    func addRecentExercise(_ exercise: ExerciseCatalogItem) {
        recentExercises.removeAll { $0.id == exercise.id }
        recentExercises.insert(exercise, at: 0)
        if recentExercises.count > 10 {
            recentExercises = Array(recentExercises.prefix(10))
        }

        persistRecentExercise(exercise)
    }

    // MARK: - Persistence

    private func loadFromPersistence() {
        do {
            let routineDescriptor = FetchDescriptor<RoutineEntity>(
                sortBy: [SortDescriptor(\RoutineEntity.updatedAt, order: .reverse)]
            )
            let routineEntities = try context.fetch(routineDescriptor)
            routines = routineEntities.map(mapRoutine)

            let recentDescriptor = FetchDescriptor<RecentExerciseEntity>(
                sortBy: [SortDescriptor(\RecentExerciseEntity.lastUsedAt, order: .reverse)]
            )
            let recentEntities = try context.fetch(recentDescriptor)
            recentExercises = Array(recentEntities.prefix(10)).map(mapRecentExercise)
        } catch {
            routines = []
            recentExercises = []
        }
    }

    private func persistRoutine(_ routine: Routine) {
        let entity = fetchRoutineEntity(id: routine.id) ?? RoutineEntity(
            id: routine.id,
            name: routine.name,
            routineDescription: routine.description,
            updatedAt: .now
        )

        if fetchRoutineEntity(id: routine.id) == nil {
            context.insert(entity)
        }

        entity.name = routine.name
        entity.routineDescription = routine.description
        entity.updatedAt = .now

        // Rebuild children to keep order and values in sync with UI source of truth.
        for exercise in entity.exercises {
            context.delete(exercise)
        }
        entity.exercises.removeAll()

        for (exerciseIndex, exercise) in routine.exercises.enumerated() {
            let setEntities = exercise.sets.enumerated().map { setIndex, set in
                WorkoutSetEntity(
                    id: set.id,
                    weight: set.weight,
                    reps: set.reps,
                    orderIndex: setIndex
                )
            }

            let exerciseEntity = ExerciseEntity(
                id: exercise.id,
                name: exercise.name,
                notes: exercise.notes,
                imageURLString: exercise.imageURL?.absoluteString,
                mediaURLString: exercise.mediaURL?.absoluteString,
                primaryMuscle: exercise.primaryMuscle,
                secondaryMuscles: exercise.secondaryMuscles,
                restMinutes: exercise.restMinutes,
                orderIndex: exerciseIndex,
                sets: setEntities
            )

            entity.exercises.append(exerciseEntity)
        }

        saveContext()
    }

    private func persistRecentExercise(_ exercise: ExerciseCatalogItem) {
        let entity = fetchRecentEntity(id: exercise.id) ?? RecentExerciseEntity(
            id: exercise.id,
            name: exercise.name,
            muscle: exercise.muscle,
            equipment: exercise.equipment,
            imageURLString: exercise.imageURL?.absoluteString,
            mediaURLString: exercise.mediaURL?.absoluteString,
            primaryMuscle: exercise.primaryMuscle,
            secondaryMuscles: exercise.secondaryMuscles,
            lastUsedAt: .now
        )

        if fetchRecentEntity(id: exercise.id) == nil {
            context.insert(entity)
        }

        entity.name = exercise.name
        entity.muscle = exercise.muscle
        entity.equipment = exercise.equipment
        entity.imageURLString = exercise.imageURL?.absoluteString
        entity.mediaURLString = exercise.mediaURL?.absoluteString
        entity.primaryMuscle = exercise.primaryMuscle
        entity.secondaryMuscles = exercise.secondaryMuscles
        entity.lastUsedAt = .now

        trimRecentEntitiesIfNeeded()
        saveContext()
    }

    private func trimRecentEntitiesIfNeeded() {
        do {
            let descriptor = FetchDescriptor<RecentExerciseEntity>(
                sortBy: [SortDescriptor(\RecentExerciseEntity.lastUsedAt, order: .reverse)]
            )
            let entities = try context.fetch(descriptor)
            if entities.count > 10 {
                for entity in entities.dropFirst(10) {
                    context.delete(entity)
                }
            }
        } catch {
            // Best effort cleanup only.
        }
    }

    private func fetchRoutineEntity(id: UUID) -> RoutineEntity? {
        let descriptor = FetchDescriptor<RoutineEntity>(
            predicate: #Predicate { $0.id == id }
        )
        return try? context.fetch(descriptor).first
    }

    private func fetchRecentEntity(id: String) -> RecentExerciseEntity? {
        let descriptor = FetchDescriptor<RecentExerciseEntity>(
            predicate: #Predicate { $0.id == id }
        )
        return try? context.fetch(descriptor).first
    }

    private func saveContext() {
        do {
            try context.save()
        } catch {
            // Keep app usable even if save fails.
        }
    }

    private func mapRoutine(_ entity: RoutineEntity) -> Routine {
        let exercises = entity.exercises
            .sorted { $0.orderIndex < $1.orderIndex }
            .map(mapExercise)

        return Routine(
            id: entity.id,
            name: entity.name,
            description: entity.routineDescription,
            exercises: exercises
        )
    }

    private func mapExercise(_ entity: ExerciseEntity) -> ExerciseEntry {
        let sets = entity.sets
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { setEntity in
                WorkoutSet(
                    id: setEntity.id,
                    weight: setEntity.weight,
                    reps: setEntity.reps
                )
            }

        return ExerciseEntry(
            id: entity.id,
            name: entity.name,
            notes: entity.notes,
            imageURL: entity.imageURLString.flatMap(URL.init(string:)),
            mediaURL: entity.mediaURLString.flatMap(URL.init(string:)),
            primaryMuscle: entity.primaryMuscle,
            secondaryMuscles: entity.secondaryMuscles,
            sets: sets,
            restMinutes: entity.restMinutes
        )
    }

    private func mapRecentExercise(_ entity: RecentExerciseEntity) -> ExerciseCatalogItem {
        ExerciseCatalogItem(
            id: entity.id,
            name: entity.name,
            muscle: entity.muscle,
            equipment: entity.equipment,
            imageURL: entity.imageURLString.flatMap(URL.init(string:)),
            mediaURL: entity.mediaURLString.flatMap(URL.init(string:)),
            primaryMuscle: entity.primaryMuscle,
            secondaryMuscles: entity.secondaryMuscles
        )
    }
}
