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

    var body: some View {
        Group {
            if session.exercises.isEmpty {
                emptyState
            } else {
                workoutList
            }
        }
        .onReceive(connectivity.$lastSessionPayload.compactMap { $0 }) { payload in
            session.applySnapshot(payload)
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

    private var workoutList: some View {
        List {
            Section {
                HStack(spacing: 6) {
                    Circle()
                        .fill(syncColor)
                        .frame(width: 8, height: 8)
                    Text("Sync en vivo")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(syncColor)
                }
            }

            Section {
                Text(session.title)
                    .font(.headline)
            }

            ForEach(session.exercises.indices, id: \.self) { exerciseIndex in
                let exercise = session.exercises[exerciseIndex]
                Section {
                    ForEach(session.exercises[exerciseIndex].sets.indices, id: \.self) { setIndex in
                        WatchSetRow(
                            exerciseId: exercise.id,
                            setId: session.exercises[exerciseIndex].sets[setIndex].id,
                            setIndexLabel: setIndex + 1,
                            set: $session.exercises[exerciseIndex].sets[setIndex],
                            onToggle: { isCompleted in
                                if !session.sessionId.isEmpty {
                                    connectivity.sendSetToggle(
                                        sessionId: session.sessionId,
                                        exerciseId: exercise.id,
                                        setId: session.exercises[exerciseIndex].sets[setIndex].id,
                                        isCompleted: isCompleted
                                    )
                                }
                                if isCompleted {
                                    beginRest(for: exercise)
                                }
                            },
                            onSendUpdate: { weight, reps in
                                guard !session.sessionId.isEmpty else { return }
                                connectivity.sendSetUpdate(
                                    sessionId: session.sessionId,
                                    exerciseId: exercise.id,
                                    setId: session.exercises[exerciseIndex].sets[setIndex].id,
                                    weight: weight,
                                    reps: reps
                                )
                            }
                        )
                    }
                } header: {
                    Text(exercise.name)
                        .font(.caption.bold())
                }
            }

            Section {
                Button {
                    finishWorkout()
                } label: {
                    HStack {
                        Spacer()
                        Text("Finish Workout")
                            .font(.headline)
                        Spacer()
                    }
                }
            }
        }
        .listStyle(.carousel)
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

    private func beginRest(for exercise: WatchWorkoutExercise) {
        let seconds = Int((exercise.restMinutes * 60).rounded())
        guard seconds > 0 else { return }
        restExerciseId = exercise.id
        restExerciseName = exercise.name
        restRemainingSeconds = seconds
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
        connectivity.sendSessionFinished(sessionId: session.sessionId)
        session.reset()
        restRemainingSeconds = nil
        restExerciseName = ""
        restExerciseId = nil
    }

    private var syncColor: Color {
        let isLive = connectivity.isReachable && connectivity.isCompanionAppInstalled
        return isLive ? .green : Color.gray.opacity(0.7)
    }
}

private enum CrownField: Hashable {
    case weight(exerciseId: String, setId: String)
    case reps(exerciseId: String, setId: String)
}

private struct WatchSetRow: View {
    let exerciseId: String
    let setId: String
    let setIndexLabel: Int

    @Binding var set: WatchWorkoutSet
    @FocusState private var focusedField: CrownField?
    let onToggle: (Bool) -> Void
    let onSendUpdate: (Double, Int) -> Void

    @State private var pendingUpdateTask: Task<Void, Never>?
    @State private var crownWeight: Double = 0
    @State private var crownReps: Double = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Set \(setIndexLabel)")
                    .font(.caption2.weight(.semibold))
                Spacer()
                Button {
                    set.isCompleted.toggle()
                    onToggle(set.isCompleted)
                } label: {
                    Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(set.isCompleted ? Color.green : Color.gray)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                crownControl(
                    title: "LBS",
                    value: formatWeight(set.weight),
                    isFocused: focusedField == .weight(exerciseId: exerciseId, setId: setId)
                ) {
                    focusedField = .weight(exerciseId: exerciseId, setId: setId)
                }
                .digitalCrownRotation(
                    $crownWeight,
                    from: 0,
                    through: 1000,
                    by: 0.5,
                    sensitivity: .medium,
                    isContinuous: true,
                    isHapticFeedbackEnabled: true
                )
                .focusable(true)
                .focused($focusedField, equals: .weight(exerciseId: exerciseId, setId: setId))
                .onChange(of: crownWeight) { _, newValue in
                    let rounded = round(newValue * 2) / 2
                    if set.weight != rounded {
                        set.weight = rounded
                        scheduleUpdate()
                    }
                }

                crownControl(
                    title: "REPS",
                    value: "\(set.reps)",
                    isFocused: focusedField == .reps(exerciseId: exerciseId, setId: setId)
                ) {
                    focusedField = .reps(exerciseId: exerciseId, setId: setId)
                }
                .digitalCrownRotation(
                    $crownReps,
                    from: 0,
                    through: 200,
                    by: 1,
                    sensitivity: .low,
                    isContinuous: true,
                    isHapticFeedbackEnabled: true
                )
                .focusable(true)
                .focused($focusedField, equals: .reps(exerciseId: exerciseId, setId: setId))
                .onChange(of: crownReps) { _, newValue in
                    let reps = max(Int(newValue.rounded()), 0)
                    if set.reps != reps {
                        set.reps = reps
                        scheduleUpdate()
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            crownWeight = set.weight
            crownReps = Double(set.reps)
        }
        .onChange(of: set.weight) { _, newValue in
            if focusedField != .weight(exerciseId: exerciseId, setId: setId) {
                crownWeight = newValue
            }
        }
        .onChange(of: set.reps) { _, newValue in
            if focusedField != .reps(exerciseId: exerciseId, setId: setId) {
                crownReps = Double(newValue)
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
