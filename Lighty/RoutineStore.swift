import Foundation
import SwiftData
import SwiftUI
internal import Combine

// MARK: - Store

final class RoutineStore: ObservableObject {
    @Published private(set) var routines: [Routine] = []
    @Published private(set) var recentExercises: [ExerciseCatalogItem] = []
    @Published private(set) var completedTrainings: [CompletedTraining] = []

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
                TrainingSessionEntity.self,
                ExerciseRecordEntity.self,
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

    func recordTraining(
        from routine: Routine,
        date: Date = .now,
        durationSeconds: Int = 0,
        volume: Double = 0,
        recordsCount: Int? = nil,
        exerciseSummaries: [CompletedTrainingExerciseSummary]? = nil
    ) {
        let summaries = exerciseSummaries ?? routine.exercises.map {
            CompletedTrainingExerciseSummary(
                id: $0.id,
                name: $0.name,
                setCount: $0.sets.count,
                imageURL: $0.imageURL
            )
        }

        let session = CompletedTraining(
            date: date,
            title: routine.name.isEmpty ? "Workout" : routine.name,
            exerciseCount: routine.exercises.count,
            durationSeconds: durationSeconds,
            volume: volume,
            recordsCount: recordsCount,
            exerciseSummaries: summaries
        )
        completedTrainings.insert(session, at: 0)
        persistTrainingSession(session)
    }

    func exerciseRecordSnapshot(for exerciseName: String) -> ExerciseRecordSnapshot {
        let key = normalizedExerciseKey(exerciseName)
        guard let entity = fetchExerciseRecordEntity(key: key) else {
            return ExerciseRecordSnapshot(
                attemptsCount: 0,
                bestWeight: 0,
                bestReps: 0,
                bestDate: nil
            )
        }

        return ExerciseRecordSnapshot(
            attemptsCount: entity.attemptsCount,
            bestWeight: entity.bestWeight,
            bestReps: entity.bestReps,
            bestDate: entity.bestAt
        )
    }

    func bestPersonalRecord(for exerciseName: String) -> ExercisePersonalRecord? {
        let key = normalizedExerciseKey(exerciseName)
        guard let entity = fetchExerciseRecordEntity(key: key),
              entity.attemptsCount > 0,
              let bestAt = entity.bestAt,
              entity.bestWeight > 0,
              entity.bestReps > 0 else {
            return nil
        }

        return ExercisePersonalRecord(
            date: bestAt,
            weight: entity.bestWeight,
            reps: entity.bestReps
        )
    }

    func persistCompletedSetRecords(_ records: [CompletedSetRecord]) -> Int {
        guard !records.isEmpty else { return 0 }

        var personalRecordsCount = 0

        for record in records {
            guard record.weight > 0, record.reps > 0 else { continue }

            let key = normalizedExerciseKey(record.exerciseName)
            let existingEntity = fetchExerciseRecordEntity(key: key)
            let entity = existingEntity ?? ExerciseRecordEntity(
                exerciseKey: key,
                exerciseName: record.exerciseName
            )

            if existingEntity == nil {
                context.insert(entity)
            }

            let hasHistory = entity.attemptsCount > 0
            let becomesNewRecord = hasHistory && isBetterRecord(
                weight: record.weight,
                reps: record.reps,
                thanWeight: entity.bestWeight,
                reps: entity.bestReps
            )

            entity.attemptsCount += 1
            entity.exerciseName = record.exerciseName

            if entity.attemptsCount == 1 || becomesNewRecord {
                entity.bestWeight = record.weight
                entity.bestReps = record.reps
                entity.bestAt = record.completedAt
            }

            if becomesNewRecord {
                personalRecordsCount += 1
            }
        }

        saveContext()
        return personalRecordsCount
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

            let sessionsDescriptor = FetchDescriptor<TrainingSessionEntity>(
                sortBy: [SortDescriptor(\TrainingSessionEntity.performedAt, order: .reverse)]
            )
            let sessions = try context.fetch(sessionsDescriptor)
            completedTrainings = sessions.map(mapTraining)
        } catch {
            routines = []
            recentExercises = []
            completedTrainings = []
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
                    orderIndex: setIndex,
                    typeRaw: set.type.rawValue
                )
            }

            let exerciseEntity = ExerciseEntity(
                id: exercise.id,
                name: exercise.name,
                notes: exercise.notes,
                imageURLString: exercise.imageURL?.absoluteString,
                mediaURLString: exercise.mediaURL?.absoluteString,
                primaryMuscle: exercise.primaryMuscle,
                secondaryMusclesCSV: encodeMuscles(exercise.secondaryMuscles),
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
            secondaryMusclesCSV: encodeMuscles(exercise.secondaryMuscles),
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
        entity.secondaryMusclesCSV = encodeMuscles(exercise.secondaryMuscles)
        entity.lastUsedAt = .now

        trimRecentEntitiesIfNeeded()
        saveContext()
    }

    private func persistTrainingSession(_ session: CompletedTraining) {
        let entity = TrainingSessionEntity(
            id: session.id,
            performedAt: session.date,
            title: session.title,
            exerciseCount: session.exerciseCount,
            durationSeconds: session.durationSeconds,
            volume: session.volume,
            recordsCount: session.recordsCount,
            averageHeartRate: session.averageHeartRate,
            exerciseSummariesJSON: encodeExerciseSummaries(session.exerciseSummaries)
        )
        context.insert(entity)
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

    private func fetchExerciseRecordEntity(key: String) -> ExerciseRecordEntity? {
        let descriptor = FetchDescriptor<ExerciseRecordEntity>(
            predicate: #Predicate { $0.exerciseKey == key }
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
                    reps: setEntity.reps,
                    type: WorkoutSetType(rawValue: setEntity.typeRaw ?? "") ?? .normal
                )
            }

        return ExerciseEntry(
            id: entity.id,
            name: entity.name,
            notes: entity.notes,
            imageURL: entity.imageURLString.flatMap(URL.init(string:)),
            mediaURL: entity.mediaURLString.flatMap(URL.init(string:)),
            primaryMuscle: entity.primaryMuscle,
            secondaryMuscles: decodeMuscles(entity.secondaryMusclesCSV),
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
            secondaryMuscles: decodeMuscles(entity.secondaryMusclesCSV)
        )
    }

    private func mapTraining(_ entity: TrainingSessionEntity) -> CompletedTraining {
        CompletedTraining(
            id: entity.id,
            date: entity.performedAt,
            title: entity.title,
            exerciseCount: entity.exerciseCount,
            durationSeconds: entity.durationSeconds ?? 0,
            volume: entity.volume ?? 0,
            recordsCount: entity.recordsCount,
            averageHeartRate: entity.averageHeartRate,
            exerciseSummaries: decodeExerciseSummaries(entity.exerciseSummariesJSON)
        )
    }

    private func encodeMuscles(_ muscles: [String]) -> String {
        muscles
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "|")
    }

    private func decodeMuscles(_ csv: String?) -> [String] {
        guard let csv else { return [] }
        return csv
            .split(separator: "|")
            .map(String.init)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func encodeExerciseSummaries(_ summaries: [CompletedTrainingExerciseSummary]) -> String? {
        guard !summaries.isEmpty else { return nil }
        do {
            let data = try JSONEncoder().encode(summaries)
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    private func decodeExerciseSummaries(_ json: String?) -> [CompletedTrainingExerciseSummary] {
        guard let json, let data = json.data(using: .utf8) else { return [] }
        do {
            return try JSONDecoder().decode([CompletedTrainingExerciseSummary].self, from: data)
        } catch {
            return []
        }
    }

    private func normalizedExerciseKey(_ name: String) -> String {
        name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private func isBetterRecord(weight candidateWeight: Double, reps candidateReps: Int, thanWeight bestWeight: Double, reps bestReps: Int) -> Bool {
        let sameOrMoreReps = candidateReps >= bestReps
        let sameOrMoreWeight = candidateWeight >= bestWeight
        let improvesWeight = candidateWeight > bestWeight && sameOrMoreReps
        let improvesReps = candidateReps > bestReps && sameOrMoreWeight
        return improvesWeight || improvesReps
    }
}
