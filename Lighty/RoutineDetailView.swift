import SwiftUI

struct RoutineDetailView: View {
    enum Mode {
        case create
        case edit(Routine.ID)
    }

    let mode: Mode

    @EnvironmentObject private var store: RoutineStore
    @Environment(\.dismiss) private var dismiss

    @State private var routine: Routine = Routine()
    @State private var showExercisePicker = false

    var body: some View {
        List {
            Section {
                TextField("Routine Name", text: $routine.name)
            } header: {
                Text("Details")
            }

            Section {
                if routine.exercises.isEmpty {
                    Text("No exercises yet")
                        .foregroundStyle(.secondary)
                }

                ForEach($routine.exercises) { $exercise in
                    ExerciseEditorView(exercise: $exercise)
                        .padding(.vertical, 6)
                }

                Button("Add Exercise") {
                    showExercisePicker = true
                }
            } header: {
                Text("Exercises")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(routine.name.isEmpty ? "Routine" : routine.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    saveRoutine()
                }
            }
        }
        .sheet(isPresented: $showExercisePicker) {
            ExercisePickerView { selectedName in
                addExercise(named: selectedName)
                showExercisePicker = false
            }
        }
        .onAppear {
            // Load existing routine data when editing.
            if case .edit(let id) = mode, let existing = store.routine(with: id) {
                routine = existing
            }
        }
    }

    private func addExercise(named name: String) {
        routine.exercises.append(ExerciseEntry(name: name))
    }

    private func saveRoutine() {
        // Persist changes back into the shared store.
        store.save(routine)
        dismiss()
    }
}

private struct ExerciseEditorView: View {
    @Binding var exercise: ExerciseEntry
    @State private var showRestPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(exercise.name)
                .font(.headline)

            setHeaderRow

            ForEach(exercise.sets.indices, id: \.self) { index in
                HStack(spacing: 12) {
                    Text("\(index + 1)")
                        .frame(width: 30, alignment: .leading)

                    TextField("0", value: $exercise.sets[index].weight, format: .number)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 110)

                    TextField("0", value: $exercise.sets[index].reps, format: .number)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                }
            }

            Button(restLabel) {
                showRestPicker = true
            }
            .font(.subheadline)

            Button("Add Set") {
                exercise.sets.append(WorkoutSet())
            }
        }
        .sheet(isPresented: $showRestPicker) {
            RestPickerView(restMinutes: $exercise.restMinutes)
        }
    }

    private var restLabel: String {
        exercise.restMinutes == 0 ? "Rest: OFF" : "Rest: \(exercise.restMinutes) min"
    }

    private var setHeaderRow: some View {
        HStack(spacing: 12) {
            Text("Set")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .leading)

            Text("Weight (LBS)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)

            Text("Reps")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
        }
    }
}

private struct RestPickerView: View {
    @Binding var restMinutes: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Picker("Rest Timer", selection: $restMinutes) {
                    ForEach(0...5, id: \.self) { minutes in
                        Text(minutes == 0 ? "OFF" : "\(minutes) min")
                            .tag(minutes)
                    }
                }
                .pickerStyle(.inline)
            }
            .navigationTitle("Rest Timer")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    RoutineDetailView(mode: .create)
        .environmentObject(RoutineStore())
}
