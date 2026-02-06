import Foundation
import SwiftUI
internal import Combine

struct WorkoutCompletionToast: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
}

struct WorkoutSessionSet: Identifiable, Hashable {
    let id: UUID
    var lastWeight: Int
    var lastReps: Int
    var weight: Int
    var reps: Int
    var isCompleted: Bool

    init(
        id: UUID = UUID(),
        lastWeight: Int = 0,
        lastReps: Int = 0,
        weight: Int = 0,
        reps: Int = 0,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.lastWeight = lastWeight
        self.lastReps = lastReps
        self.weight = weight
        self.reps = reps
        self.isCompleted = isCompleted
    }

    init(from set: WorkoutSet) {
        id = set.id
        lastWeight = set.weight
        lastReps = set.reps
        weight = set.weight
        reps = set.reps
        isCompleted = false
    }
}

struct WorkoutSessionExercise: Identifiable, Hashable {
    let id: UUID
    var name: String
    var notes: String
    var imageURL: URL?
    var mediaURL: URL?
    var primaryMuscle: String
    var secondaryMuscles: [String]
    var restMinutes: Double
    var sets: [WorkoutSessionSet]

    init(from exercise: ExerciseEntry) {
        id = exercise.id
        name = exercise.name
        notes = exercise.notes
        imageURL = exercise.imageURL
        mediaURL = exercise.mediaURL
        primaryMuscle = exercise.primaryMuscle
        secondaryMuscles = exercise.secondaryMuscles
        restMinutes = exercise.restMinutes
        sets = exercise.sets.map(WorkoutSessionSet.init(from:))
    }

    init(from catalog: ExerciseCatalogItem) {
        id = UUID()
        name = catalog.name
        notes = ""
        imageURL = catalog.imageURL
        mediaURL = catalog.mediaURL
        primaryMuscle = catalog.primaryMuscle
        secondaryMuscles = catalog.secondaryMuscles
        restMinutes = 0
        sets = [WorkoutSessionSet(), WorkoutSessionSet()]
    }

    func toExerciseEntry() -> ExerciseEntry {
        ExerciseEntry(
            id: id,
            name: name,
            notes: notes,
            imageURL: imageURL,
            mediaURL: mediaURL,
            primaryMuscle: primaryMuscle,
            secondaryMuscles: secondaryMuscles,
            sets: sets.map { WorkoutSet(id: $0.id, weight: $0.weight, reps: $0.reps) },
            restMinutes: restMinutes
        )
    }
}

@MainActor
final class WorkoutSessionManager: ObservableObject {
    @Published private(set) var isActive = false
    @Published var isWorkoutPresented = false
    @Published var isMinimized = false
    @Published var title = "Workout"
    @Published var exercises: [WorkoutSessionExercise] = []
    @Published private(set) var elapsedSeconds = 0
    @Published var restRemainingSeconds: Int?
    @Published private(set) var restExerciseName = ""
    @Published private(set) var sourceRoutineID: UUID?
    @Published private(set) var sourceRoutineDescription: String = ""
    @Published private(set) var sourceRoutineExercises: [ExerciseEntry] = []
    @Published var completionToast: WorkoutCompletionToast?

    private var startedAt: Date?
    private var elapsedTicker: AnyCancellable?
    private var restTicker: AnyCancellable?

    func begin(from routine: Routine) {
        stopTimers()

        sourceRoutineID = routine.id
        sourceRoutineDescription = routine.description
        sourceRoutineExercises = routine.exercises

        startSession(
            title: routine.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Workout" : routine.name,
            exercises: routine.exercises.map(WorkoutSessionExercise.init(from:))
        )
    }

    func beginEmptyWorkout() {
        stopTimers()
        sourceRoutineID = nil
        sourceRoutineDescription = ""
        sourceRoutineExercises = []

        startSession(title: "Empty Workout", exercises: [])
    }

    func restore() {
        guard isActive else { return }
        isMinimized = false
        isWorkoutPresented = true
    }

    func minimize() {
        guard isActive else { return }
        isMinimized = true
        isWorkoutPresented = false
    }

    func finish(using store: RoutineStore, updateRoutine: Bool) {
        guard isActive else { return }

        let finishedElapsed = elapsedSeconds
        let finishedSets = completedSetsCount
        let finishedVolume = totalVolume
        let updatedExercises = exercises.map { $0.toExerciseEntry() }
        let completedRoutine = Routine(
            name: title,
            description: "",
            exercises: updatedExercises
        )

        store.recordTraining(from: completedRoutine)

        if updateRoutine, let sourceRoutineID {
            let updatedRoutine = Routine(
                id: sourceRoutineID,
                name: title,
                description: sourceRoutineDescription,
                exercises: updatedExercises
            )
            store.save(updatedRoutine)
        }

        completionToast = buildCompletionToast(
            elapsedSeconds: finishedElapsed,
            sets: finishedSets,
            volume: finishedVolume,
            updatedRoutine: updateRoutine
        )

        endSession()
    }

    func clearCompletionToast() {
        completionToast = nil
    }

    func discard() {
        endSession()
    }

    func addExercise(from catalog: ExerciseCatalogItem) {
        var updated = exercises
        updated.append(WorkoutSessionExercise(from: catalog))
        exercises = updated
    }

    func addSet(exerciseIndex: Int) {
        guard exercises.indices.contains(exerciseIndex) else { return }

        var updated = exercises
        updated[exerciseIndex].sets.append(WorkoutSessionSet())
        exercises = updated
    }

    func setRestMinutes(_ minutes: Double, for exerciseIndex: Int) {
        guard exercises.indices.contains(exerciseIndex) else { return }

        var updated = exercises
        updated[exerciseIndex].restMinutes = minutes
        exercises = updated
    }

    func toggleSetCompletion(exerciseIndex: Int, setIndex: Int) {
        guard exercises.indices.contains(exerciseIndex),
              exercises[exerciseIndex].sets.indices.contains(setIndex) else {
            return
        }

        var updated = exercises
        updated[exerciseIndex].sets[setIndex].isCompleted.toggle()
        let isNowCompleted = updated[exerciseIndex].sets[setIndex].isCompleted
        let restMinutes = updated[exerciseIndex].restMinutes
        let exerciseName = updated[exerciseIndex].name
        exercises = updated

        if isNowCompleted {
            startRestIfNeeded(
                restMinutes: restMinutes,
                exerciseName: exerciseName
            )
        }
    }

    func addRest(seconds: Int) {
        let current = restRemainingSeconds ?? 0
        let next = max(current + seconds, 0)
        restRemainingSeconds = next == 0 ? nil : next
        if next == 0 {
            restTicker?.cancel()
        } else if restTicker == nil {
            startRestTimer()
        }
    }

    func skipRest() {
        restRemainingSeconds = nil
        restExerciseName = ""
        restTicker?.cancel()
        restTicker = nil
    }

    var completedSetsCount: Int {
        exercises
            .flatMap(\.sets)
            .filter(\.isCompleted)
            .count
    }

    var totalVolume: Int {
        exercises
            .flatMap(\.sets)
            .filter(\.isCompleted)
            .reduce(0) { partial, set in
                partial + (set.weight * set.reps)
            }
    }

    var elapsedLabel: String {
        Self.formatElapsed(elapsedSeconds)
    }

    var restLabel: String {
        guard let restRemainingSeconds else { return "0:00" }
        let minutes = restRemainingSeconds / 60
        let seconds = restRemainingSeconds % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }

    var canUpdateSourceRoutine: Bool {
        sourceRoutineID != nil
    }

    var hasRoutineChanges: Bool {
        guard canUpdateSourceRoutine else { return false }
        return sourceRoutineExercises != exercises.map { $0.toExerciseEntry() }
    }

    private func endSession() {
        stopTimers()
        isActive = false
        isWorkoutPresented = false
        isMinimized = false
        title = "Workout"
        exercises = []
        elapsedSeconds = 0
        restRemainingSeconds = nil
        restExerciseName = ""
        startedAt = nil
        sourceRoutineID = nil
        sourceRoutineDescription = ""
        sourceRoutineExercises = []
    }

    private func startSession(title: String, exercises: [WorkoutSessionExercise]) {
        self.title = title
        self.exercises = exercises
        isActive = true
        isMinimized = false
        isWorkoutPresented = true

        startedAt = .now
        elapsedSeconds = 0
        restRemainingSeconds = nil
        restExerciseName = ""
        startElapsedTimer()
    }

    private func startElapsedTimer() {
        elapsedTicker?.cancel()
        elapsedTicker = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateElapsed()
            }
    }

    private func updateElapsed() {
        guard let startedAt else {
            elapsedSeconds = 0
            return
        }
        elapsedSeconds = max(Int(Date().timeIntervalSince(startedAt)), 0)
    }

    private func startRestIfNeeded(restMinutes: Double, exerciseName: String) {
        let seconds = Int((restMinutes * 60).rounded())
        guard seconds > 0 else { return }

        restExerciseName = exerciseName
        restRemainingSeconds = seconds
        startRestTimer()
    }

    private func startRestTimer() {
        restTicker?.cancel()
        restTicker = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, let remaining = self.restRemainingSeconds else { return }
                if remaining <= 1 {
                    self.skipRest()
                } else {
                    self.restRemainingSeconds = remaining - 1
                }
            }
    }

    private func stopTimers() {
        elapsedTicker?.cancel()
        elapsedTicker = nil
        restTicker?.cancel()
        restTicker = nil
    }

    private static func formatElapsed(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return "\(hours)h \(minutes)min \(seconds)s"
        }

        return "\(minutes)min \(seconds)s"
    }

    private func buildCompletionToast(
        elapsedSeconds: Int,
        sets: Int,
        volume: Int,
        updatedRoutine: Bool
    ) -> WorkoutCompletionToast {
        let duration = Self.formatElapsed(elapsedSeconds)
        let title = updatedRoutine ? "Routine leveled up" : "Workout complete"
        let icon = updatedRoutine ? "sparkles" : "flame.fill"
        let subtitle = "Great job. \(duration), \(sets) sets, \(volume) lbs moved. Keep showing up."
        return WorkoutCompletionToast(title: title, subtitle: subtitle, icon: icon)
    }
}

struct WorkoutSessionView: View {
    @EnvironmentObject private var store: RoutineStore
    @EnvironmentObject private var workoutSession: WorkoutSessionManager

    @State private var showExercisePicker = false
    @State private var selectedExerciseID: WorkoutSessionExercise.ID?
    @State private var showSettingsNotice = false
    @State private var restPickerExerciseIndex: Int?
    @State private var showFinishOptions = false

    var body: some View {
        ZStack(alignment: .bottom) {
            AppBackgroundLayer()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal)
                    .padding(.top, 10)
                    .padding(.bottom, 8)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        metricsBar

                        if workoutSession.exercises.isEmpty {
                            emptyExercises
                        }

                        ForEach(Array(workoutSession.exercises.enumerated()), id: \.element.id) { index, exercise in
                            exerciseCard(exercise, exerciseIndex: index)
                        }

                        Button {
                            showExercisePicker = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Exercise")
                                Spacer()
                            }
                        }
                        .buttonStyle(SoftFillButtonStyle())

                        HStack(spacing: 12) {
                            Button {
                                showSettingsNotice = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "gearshape.fill")
                                    Text("General Settings")
                                    Spacer()
                                }
                            }
                            .buttonStyle(SoftFillButtonStyle())

                            Button {
                                workoutSession.discard()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "trash.fill")
                                    Text("Discard Workout")
                                    Spacer()
                                }
                            }
                            .buttonStyle(SoftFillButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 130)
                }
                .scrollIndicators(.hidden)
            }

            if workoutSession.restRemainingSeconds != nil {
                restPanel
                    .padding(.horizontal)
                    .padding(.bottom, 18)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showExercisePicker) {
            AddExerciseCatalogView { selected in
                workoutSession.addExercise(from: selected)
                showExercisePicker = false
            }
        }
        .sheet(
            isPresented: Binding(
                get: { restPickerExerciseIndex != nil },
                set: { if !$0 { restPickerExerciseIndex = nil } }
            )
        ) {
            if let restPickerExerciseIndex,
               workoutSession.exercises.indices.contains(restPickerExerciseIndex) {
                LiveRestPickerView(
                    selectedMinutes: workoutSession.exercises[restPickerExerciseIndex].restMinutes
                ) { selected in
                    workoutSession.setRestMinutes(selected, for: restPickerExerciseIndex)
                    self.restPickerExerciseIndex = nil
                }
            }
        }
        .sheet(
            isPresented: Binding(
                get: { selectedExerciseID != nil },
                set: { if !$0 { selectedExerciseID = nil } }
            )
        ) {
            if let selectedExerciseID,
               let binding = exerciseBinding(for: selectedExerciseID) {
                ExerciseInsightsView(exercise: binding)
            }
        }
        .alert("General configuration", isPresented: $showSettingsNotice) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This section will be implemented in a next step.")
        }
        .confirmationDialog(
            "Rutina actualizada",
            isPresented: $showFinishOptions,
            titleVisibility: .visible
        ) {
            Button("Guardar entreno y actualizar rutina") {
                workoutSession.finish(using: store, updateRoutine: true)
            }
            Button("Guardar solo entreno") {
                workoutSession.finish(using: store, updateRoutine: false)
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Este entreno modificó la rutina. ¿Quieres guardar esos cambios en la rutina también?")
        }
        .interactiveDismissDisabled()
    }

    private var topBar: some View {
        ZStack {
            Text(workoutSession.title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(StyleKit.ink)
                .lineLimit(1)
                .padding(.horizontal, 90)

            HStack {
                Button {
                    workoutSession.minimize()
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(StyleKit.ink)
                        .frame(width: 34, height: 34)
                        .background(StyleKit.softChip.opacity(0.85))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Spacer()

                Button("Finish") {
                    if workoutSession.hasRoutineChanges {
                        showFinishOptions = true
                    } else {
                        workoutSession.finish(using: store, updateRoutine: false)
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(StyleKit.accentBlue)
            }
        }
    }

    private var metricsBar: some View {
        HStack(spacing: 10) {
            metricTile(title: "Duration", value: workoutSession.elapsedLabel, icon: "clock.fill")
            metricTile(title: "Volume", value: "\(workoutSession.totalVolume) lbs", icon: "scalemass.fill")
            metricTile(title: "Sets", value: "\(workoutSession.completedSetsCount)", icon: "checkmark.circle.fill")
        }
    }

    private var emptyExercises: some View {
        VStack(spacing: 10) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.title2)
                .foregroundStyle(StyleKit.accentBlue)

            Text("Add your first exercise")
                .font(.headline)
                .foregroundStyle(StyleKit.ink)

            Text("Start adding movements and complete sets to track stats live.")
                .font(.subheadline)
                .foregroundStyle(StyleKit.softInk)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .appCard(padding: 14, radius: 16)
    }

    private func metricTile(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(StyleKit.accentBlue)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(StyleKit.ink)
                .lineLimit(1)
            Text(title)
                .font(.caption)
                .foregroundStyle(StyleKit.softInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard(padding: 12, radius: 14)
    }

    private func exerciseCard(_ exercise: WorkoutSessionExercise, exerciseIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                selectedExerciseID = exercise.id
            } label: {
                HStack(spacing: 8) {
                    ExerciseRowThumbnail(imageURL: exercise.imageURL)
                    Text(exercise.name)
                        .font(.headline)
                        .foregroundStyle(StyleKit.accentBlue)
                    Spacer()
                }
            }
            .buttonStyle(.plain)

            TextField("Write your notes here", text: $workoutSession.exercises[exerciseIndex].notes, axis: .vertical)
                .lineLimit(3, reservesSpace: true)
                .padding(10)
                .background(StyleKit.softChip.opacity(0.75))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Button(restLabel(for: exercise.restMinutes)) {
                restPickerExerciseIndex = exerciseIndex
            }
            .buttonStyle(.plain)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(StyleKit.accentBlue)

            setHeaderRow

            ForEach(exercise.sets.indices, id: \.self) { setIndex in
                let set = workoutSession.exercises[exerciseIndex].sets[setIndex]
                HStack(spacing: 10) {
                    Text("\(setIndex + 1)")
                        .frame(width: 30, alignment: .leading)
                        .foregroundStyle(StyleKit.softInk)

                    Text(lastSetLabel(set))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(StyleKit.softInk)
                        .frame(width: 72, alignment: .leading)

                    TextField("0", value: $workoutSession.exercises[exerciseIndex].sets[setIndex].weight, format: .number)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.plain)
                        .frame(width: 72)

                    TextField("0", value: $workoutSession.exercises[exerciseIndex].sets[setIndex].reps, format: .number)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.plain)
                        .frame(width: 58)

                    Spacer(minLength: 0)

                    Button {
                        workoutSession.toggleSetCompletion(exerciseIndex: exerciseIndex, setIndex: setIndex)
                    } label: {
                        Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(set.isCompleted ? StyleKit.accentBlue : StyleKit.softInk)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(setIndex.isMultiple(of: 2) ? Color.white.opacity(0.46) : StyleKit.softChip.opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Button {
                workoutSession.addSet(exerciseIndex: exerciseIndex)
            } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("Add Set")
                    Spacer()
                }
            }
            .buttonStyle(SoftFillButtonStyle())
        }
        .appCard(padding: 14, radius: 16)
    }

    private var setHeaderRow: some View {
        HStack(spacing: 10) {
            Text("Set")
                .font(.caption.weight(.semibold))
                .foregroundStyle(StyleKit.softInk)
                .frame(width: 30, alignment: .leading)

            Text("Last")
                .font(.caption.weight(.semibold))
                .foregroundStyle(StyleKit.softInk)
                .frame(width: 72, alignment: .leading)

            Text("LBS")
                .font(.caption.weight(.semibold))
                .foregroundStyle(StyleKit.softInk)
                .frame(width: 72, alignment: .leading)

            Text("REPS")
                .font(.caption.weight(.semibold))
                .foregroundStyle(StyleKit.softInk)
                .frame(width: 58, alignment: .leading)

            Spacer()

            Image(systemName: "checkmark")
                .font(.caption.weight(.bold))
                .foregroundStyle(StyleKit.softInk)
        }
    }

    private var restPanel: some View {
        VStack(spacing: 12) {
            if !workoutSession.restExerciseName.isEmpty {
                Text("Rest • \(workoutSession.restExerciseName)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(StyleKit.softInk)
            }

            Text(workoutSession.restLabel)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(StyleKit.ink)

            HStack(spacing: 10) {
                Button {
                    workoutSession.addRest(seconds: -15)
                } label: {
                    Text("-15s")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SoftFillButtonStyle())

                Button {
                    workoutSession.addRest(seconds: 15)
                } label: {
                    Text("+15s")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SoftFillButtonStyle())

                Button {
                    workoutSession.skipRest()
                } label: {
                    Text("Skip")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SoftFillButtonStyle())
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.97))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.95), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.08), radius: 12, y: 5)
    }

    private func restLabel(for restMinutes: Double) -> String {
        guard restMinutes > 0 else { return "Rest: OFF" }
        let wholeMinutes = Int(restMinutes)
        let hasHalf = restMinutes.truncatingRemainder(dividingBy: 1) != 0
        return hasHalf ? "Rest: \(wholeMinutes).30 min" : "Rest: \(wholeMinutes) min"
    }

    private func lastSetLabel(_ set: WorkoutSessionSet) -> String {
        guard set.lastWeight > 0 || set.lastReps > 0 else { return "-" }
        return "\(set.lastWeight)x\(set.lastReps)"
    }

    private func exerciseBinding(for id: WorkoutSessionExercise.ID) -> Binding<ExerciseEntry>? {
        guard let index = workoutSession.exercises.firstIndex(where: { $0.id == id }) else {
            return nil
        }

        return Binding(
            get: { workoutSession.exercises[index].toExerciseEntry() },
            set: { updated in
                workoutSession.exercises[index].name = updated.name
                workoutSession.exercises[index].notes = updated.notes
                workoutSession.exercises[index].imageURL = updated.imageURL
                workoutSession.exercises[index].mediaURL = updated.mediaURL
                workoutSession.exercises[index].primaryMuscle = updated.primaryMuscle
                workoutSession.exercises[index].secondaryMuscles = updated.secondaryMuscles
            }
        )
    }
}

private struct LiveRestPickerView: View {
    let selectedMinutes: Double
    let onSelect: (Double) -> Void

    private let restOptions = stride(from: 0.0, through: 5.0, by: 0.5).map { $0 }

    var body: some View {
        NavigationStack {
            List {
                ForEach(restOptions, id: \.self) { option in
                    Button {
                        onSelect(option)
                    } label: {
                        HStack {
                            Text(label(for: option))
                                .foregroundStyle(StyleKit.ink)
                            Spacer()
                            if option == selectedMinutes {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(StyleKit.accentBlue)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackgroundLayer())
            .navigationTitle("Rest Timer")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func label(for minutes: Double) -> String {
        if minutes == 0 { return "OFF" }
        let wholeMinutes = Int(minutes)
        let hasHalf = minutes.truncatingRemainder(dividingBy: 1) != 0
        return hasHalf ? "\(wholeMinutes).30 min" : "\(wholeMinutes) min"
    }
}

#Preview {
    WorkoutSessionView()
        .environmentObject(RoutineStore())
        .environmentObject(WorkoutSessionManager())
}
