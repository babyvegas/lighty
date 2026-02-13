//
//  ContentView.swift
//  LightyWatch Watch App
//
//  Created by Donovan Efrain Barrientos Abarca on 06/02/26.
//

import SwiftUI
internal import Combine

struct ContentView: View {
    @EnvironmentObject private var connectivity: WatchConnectivityCoordinator
    @StateObject private var session = WatchWorkoutSessionManager()

    @State private var restRemainingSeconds: Int?
    @State private var restExerciseName = ""
    @State private var restExerciseId: String?
    @State private var shouldAdvanceAfterRest = false

    @State private var currentExerciseIndex = 0
    @State private var currentSetIndex = 0

    var body: some View {
        Group {
            if session.exercises.isEmpty {
                emptyState
            } else {
                activeWorkoutView
            }
        }
        .onReceive(connectivity.$lastSessionPayload.compactMap { $0 }) { payload in
            session.applySnapshot(payload)
            normalizeIndices()
        }
        .onReceive(connectivity.$lastRestPayload.compactMap { $0 }) { payload in
            guard let seconds = payload["remainingSeconds"] as? Int else { return }
            let name = payload["exerciseName"] as? String ?? ""
            let exerciseId = payload["exerciseId"] as? String
            if seconds <= 0 {
                restRemainingSeconds = nil
                restExerciseName = ""
                restExerciseId = nil
            } else {
                restRemainingSeconds = seconds
                restExerciseName = name
                restExerciseId = exerciseId
            }
        }
        .onReceive(connectivity.$didReceiveSessionFinished) { finished in
            guard finished else { return }
            session.reset()
            restRemainingSeconds = nil
            restExerciseName = ""
            restExerciseId = nil
            connectivity.didReceiveSessionFinished = false
        }
        .onReceive(connectivity.$didReceiveSessionDiscarded) { discarded in
            guard discarded else { return }
            session.reset()
            restRemainingSeconds = nil
            restExerciseName = ""
            restExerciseId = nil
            connectivity.didReceiveSessionDiscarded = false
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { restRemainingSeconds != nil },
                set: { if !$0 { restRemainingSeconds = nil } }
            )
        ) {
            WatchRestCountdownView(
                exerciseName: restExerciseName,
                remainingSeconds: Binding(
                    get: { restRemainingSeconds ?? 0 },
                    set: { restRemainingSeconds = $0 }
                ),
                onAdjust: { delta in
                    adjustRest(by: delta)
                },
                onSkip: {
                    skipRest()
                }
            )
        }
    }

    private var activeWorkoutView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(syncColor)
                        .frame(width: 8, height: 8)
                    Text("Sync en vivo")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(syncColor)
                }
                .padding(.horizontal, 6)

                if let exercise = currentExercise,
                   let setBinding = currentSetBinding {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(exercise.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(2)

                        HStack(spacing: 8) {
                            Text("Serie actual")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text("Serie \(currentSetIndex + 1) / \(exercise.sets.count)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.blue)
                        }
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.gray.opacity(0.12))
                    )

                    WatchActiveSetView(
                        exerciseId: exercise.id,
                        setId: exercise.sets[currentSetIndex].id,
                        set: setBinding,
                        previousLabel: previousLabel(for: exercise.sets[currentSetIndex]),
                        onSendUpdate: { weight, reps in
                            guard !session.sessionId.isEmpty else { return }
                            connectivity.sendSetUpdate(
                                sessionId: session.sessionId,
                                exerciseId: exercise.id,
                                setId: exercise.sets[currentSetIndex].id,
                                weight: weight,
                                reps: reps
                            )
                        },
                        onComplete: { isCompleted in
                            if !session.sessionId.isEmpty {
                                connectivity.sendSetToggle(
                                    sessionId: session.sessionId,
                                    exerciseId: exercise.id,
                                    setId: exercise.sets[currentSetIndex].id,
                                    isCompleted: isCompleted
                                )
                            }
                            if isCompleted {
                                handleSetCompletion(for: exercise)
                            }
                        },
                        onPrev: { goToPreviousSet() },
                        onNext: { goToNextSet() },
                        onAddSet: { addSet(in: exercise) },
                        onDeleteSet: { deleteSet(in: exercise) },
                        canDelete: exercise.sets.count > 1
                    )
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.06))
                    )

                    HStack(spacing: 8) {
                        Button("Finalizar") {
                            finishWorkout()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)

                        Button("Descartar") {
                            discardWorkout()
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No workout yet")
                .font(.headline)
            Text("Start a workout on iPhone to sync here.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private var currentExercise: WatchWorkoutExercise? {
        guard session.exercises.indices.contains(currentExerciseIndex) else { return nil }
        return session.exercises[currentExerciseIndex]
    }

    private var currentSetBinding: Binding<WatchWorkoutSet>? {
        guard session.exercises.indices.contains(currentExerciseIndex),
              session.exercises[currentExerciseIndex].sets.indices.contains(currentSetIndex) else {
            return nil
        }
        return $session.exercises[currentExerciseIndex].sets[currentSetIndex]
    }

    private func normalizeIndices() {
        if session.exercises.isEmpty {
            currentExerciseIndex = 0
            currentSetIndex = 0
            return
        }
        if currentExerciseIndex >= session.exercises.count {
            currentExerciseIndex = max(session.exercises.count - 1, 0)
        }
        let setsCount = session.exercises[currentExerciseIndex].sets.count
        if setsCount == 0 {
            currentSetIndex = 0
        } else if currentSetIndex >= setsCount {
            currentSetIndex = max(setsCount - 1, 0)
        }
    }

    private func goToNextSet() {
        guard let exercise = currentExercise else { return }
        if currentSetIndex + 1 < exercise.sets.count {
            currentSetIndex += 1
            return
        }
        if currentExerciseIndex + 1 < session.exercises.count {
            currentExerciseIndex += 1
            currentSetIndex = 0
        }
    }

    private func goToPreviousSet() {
        if currentSetIndex > 0 {
            currentSetIndex -= 1
            return
        }
        if currentExerciseIndex > 0 {
            currentExerciseIndex -= 1
            let setsCount = session.exercises[currentExerciseIndex].sets.count
            currentSetIndex = max(setsCount - 1, 0)
        }
    }

    private func addSet(in exercise: WatchWorkoutExercise) {
        guard !session.sessionId.isEmpty else { return }
        let newSetId = UUID().uuidString
        session.addSet(exerciseId: exercise.id, newSetId: newSetId)
        connectivity.sendSetAdded(
            sessionId: session.sessionId,
            exerciseId: exercise.id,
            setId: newSetId
        )
        normalizeIndices()
        if let setsCount = currentExercise?.sets.count {
            currentSetIndex = max(setsCount - 1, 0)
        }
    }

    private func deleteSet(in exercise: WatchWorkoutExercise) {
        guard exercise.sets.count > 1 else { return }
        guard !session.sessionId.isEmpty else { return }
        let setId = exercise.sets[currentSetIndex].id
        session.deleteSet(exerciseId: exercise.id, setId: setId)
        connectivity.sendSetDeleted(
            sessionId: session.sessionId,
            exerciseId: exercise.id,
            setId: setId
        )
        normalizeIndices()
    }

    private func previousLabel(for set: WatchWorkoutSet) -> String {
        guard set.lastWeight > 0 || set.lastReps > 0 else { return "Anterior: -" }
        let weightLabel = formatWeight(set.lastWeight)
        return "Anterior: \(weightLabel) lb x \(set.lastReps)"
    }

    private func beginRest(for exercise: WatchWorkoutExercise) {
        let seconds = Int((exercise.restMinutes * 60).rounded())
        guard seconds > 0 else { return }
        restExerciseId = exercise.id
        restExerciseName = exercise.name
        restRemainingSeconds = seconds
    }

    private func handleSetCompletion(for exercise: WatchWorkoutExercise) {
        let seconds = Int((exercise.restMinutes * 60).rounded())
        if seconds > 0 {
            shouldAdvanceAfterRest = true
            beginRest(for: exercise)
        } else {
            shouldAdvanceAfterRest = false
            goToNextSet()
        }
    }

    private func adjustRest(by delta: Int) {
        guard let current = restRemainingSeconds else { return }
        let updated = max(current + delta, 0)
        if updated == 0 {
            skipRest()
            return
        }
        restRemainingSeconds = updated
        sendRestAdjustment(seconds: updated)
    }

    private func skipRest() {
        let hadRest = restRemainingSeconds != nil
        let exerciseId = restExerciseId
        restRemainingSeconds = nil
        restExerciseName = ""
        if shouldAdvanceAfterRest {
            shouldAdvanceAfterRest = false
            goToNextSet()
        }
        if hadRest {
            sendRestAdjustment(seconds: 0, exerciseId: exerciseId)
        }
        restExerciseId = nil
    }

    private func sendRestAdjustment(seconds: Int, exerciseId: String? = nil) {
        guard !session.sessionId.isEmpty else { return }
        guard let resolvedExerciseId = exerciseId ?? restExerciseId else { return }
        connectivity.sendRestAdjustment(
            sessionId: session.sessionId,
            exerciseId: resolvedExerciseId,
            remainingSeconds: seconds,
            exerciseName: restExerciseName
        )
    }

    private func finishWorkout() {
        guard !session.sessionId.isEmpty else {
            session.reset()
            return
        }
        let sessionId = session.sessionId
        let finalSetSnapshot: (exerciseId: String, setId: String, weight: Double, reps: Int)? = {
            guard let exercise = currentExercise,
                  exercise.sets.indices.contains(currentSetIndex) else {
                return nil
            }
            let set = exercise.sets[currentSetIndex]
            return (exercise.id, set.id, set.weight, set.reps)
        }()

        Task { @MainActor in
            if let finalSetSnapshot {
                connectivity.sendSetUpdate(
                    sessionId: sessionId,
                    exerciseId: finalSetSnapshot.exerciseId,
                    setId: finalSetSnapshot.setId,
                    weight: finalSetSnapshot.weight,
                    reps: finalSetSnapshot.reps
                )
                try? await Task.sleep(nanoseconds: 180_000_000)
                connectivity.sendSessionFinished(
                    sessionId: sessionId,
                    exerciseId: finalSetSnapshot.exerciseId,
                    setId: finalSetSnapshot.setId,
                    weight: finalSetSnapshot.weight,
                    reps: finalSetSnapshot.reps
                )
            } else {
                connectivity.sendSessionFinished(sessionId: sessionId)
            }
        }

        resetLocalWorkoutState()
    }

    private func discardWorkout() {
        guard !session.sessionId.isEmpty else {
            session.reset()
            return
        }
        connectivity.sendSessionDiscarded(sessionId: session.sessionId)
        resetLocalWorkoutState()
    }

    private var syncColor: Color {
        let isLive = connectivity.isReachable && connectivity.isCompanionAppInstalled
        return isLive ? .green : Color.gray.opacity(0.7)
    }

    private func formatWeight(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(value))"
        }
        return String(format: "%.1f", value)
    }

    private func resetLocalWorkoutState() {
        session.reset()
        restRemainingSeconds = nil
        restExerciseName = ""
        restExerciseId = nil
        shouldAdvanceAfterRest = false
        currentExerciseIndex = 0
        currentSetIndex = 0
    }
}

private enum CrownField: Hashable {
    case weight
    case reps
}

private struct WatchActiveSetView: View {
    let exerciseId: String
    let setId: String
    @Binding var set: WatchWorkoutSet
    let previousLabel: String

    let onSendUpdate: (Double, Int) -> Void
    let onComplete: (Bool) -> Void
    let onPrev: () -> Void
    let onNext: () -> Void
    let onAddSet: () -> Void
    let onDeleteSet: () -> Void
    let canDelete: Bool

    @FocusState private var crownFocused: Bool
    @State private var selectedField: CrownField = .weight
    @State private var crownValue: Double = 0
    @State private var pendingUpdateTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                crownControl(
                    title: "LBS",
                    value: formatWeight(set.weight),
                    isFocused: selectedField == .weight
                ) {
                    selectedField = .weight
                    crownFocused = true
                    updateCrownValue()
                }

                crownControl(
                    title: "REPS",
                    value: "\(set.reps)",
                    isFocused: selectedField == .reps
                ) {
                    selectedField = .reps
                    crownFocused = true
                    updateCrownValue()
                }
            }

            Text(previousLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button {
                    onPrev()
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.bordered)

                Button {
                    set.isCompleted.toggle()
                    onComplete(set.isCompleted)
                } label: {
                    Image(systemName: "checkmark")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.blue)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Button {
                    onNext()
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.bordered)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Opciones de la serie")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                Button("Añadir serie") {
                    onAddSet()
                }
                .buttonStyle(.bordered)

                Button("Eliminar serie") {
                    onDeleteSet()
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(!canDelete)
            }
            .padding(.top, 6)
        }
        .focusable(true)
        .focused($crownFocused)
        .digitalCrownRotation(
            $crownValue,
            from: 0,
            through: selectedField == .weight ? 1000 : 200,
            // Smaller crown steps make the interaction feel less jumpy.
            by: selectedField == .weight ? 0.25 : 0.5,
            sensitivity: .low,
            isContinuous: true,
            isHapticFeedbackEnabled: true
        )
        .onAppear {
            updateCrownValue()
            crownFocused = true
        }
        .onChange(of: selectedField) { _, _ in
            updateCrownValue()
        }
        .onChange(of: crownValue) { _, newValue in
            if selectedField == .weight {
                let rounded = round(newValue * 2) / 2
                if set.weight != rounded {
                    set.weight = rounded
                    scheduleUpdate()
                }
            } else {
                let reps = max(Int(newValue.rounded()), 0)
                if set.reps != reps {
                    set.reps = reps
                    scheduleUpdate()
                }
            }
        }
        .onChange(of: set.weight) { _, newValue in
            if selectedField == .weight {
                crownValue = newValue
            }
        }
        .onChange(of: set.reps) { _, newValue in
            if selectedField == .reps {
                crownValue = Double(newValue)
            }
        }
    }

    private func scheduleUpdate() {
        pendingUpdateTask?.cancel()
        let weight = set.weight
        let reps = set.reps
        pendingUpdateTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            if Task.isCancelled { return }
            onSendUpdate(weight, reps)
        }
    }

    private func crownControl(title: String, value: String, isFocused: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(Color.gray.opacity(0.15))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isFocused ? Color.blue : Color.clear, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func updateCrownValue() {
        if selectedField == .weight {
            crownValue = set.weight
        } else {
            crownValue = Double(set.reps)
        }
    }

    private func formatWeight(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(value))"
        }
        return String(format: "%.1f", value)
    }
}

private struct WatchRestCountdownView: View {
    let exerciseName: String
    @Binding var remainingSeconds: Int
    let onAdjust: (Int) -> Void
    let onSkip: () -> Void

    @State private var ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 12) {
            Text("Rest")
                .font(.headline)
            if !exerciseName.isEmpty {
                Text(exerciseName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Text(restLabel)
                .font(.system(size: 36, weight: .bold, design: .rounded))

            HStack(spacing: 8) {
                Button("-15s") { onAdjust(-15) }
                    .frame(maxWidth: .infinity)
                Button("+15s") { onAdjust(15) }
                    .frame(maxWidth: .infinity)
            }
            Button("Skip") { onSkip() }
                .frame(maxWidth: .infinity)
        }
        .padding()
        .onReceive(ticker) { _ in
            if remainingSeconds <= 1 {
                onSkip()
            } else {
                remainingSeconds -= 1
            }
        }
    }

    private var restLabel: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchConnectivityCoordinator())
}
