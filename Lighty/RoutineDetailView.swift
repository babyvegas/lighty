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
                VStack(alignment: .leading, spacing: 10) {
                    TextField("", text: $routine.name, prompt: Text("New Routine"))
                        .font(.title2)
                        .fontWeight(.bold)
                        .textFieldStyle(.plain)

                    TextField("Routine description", text: $routine.description, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                        .textFieldStyle(.plain)
                }
                .padding(.vertical, 4)
            }

            Section {
                if routine.exercises.isEmpty {
                    Text("No exercises yet")
                        .foregroundStyle(.secondary)
                }

                ForEach($routine.exercises) { $exercise in
                    ExerciseEditorView(exercise: $exercise)
                        .padding(.vertical, 8)
                }

                Button("Add Exercise") {
                    showExercisePicker = true
                }
                .padding(.vertical, 6)
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
        VStack(alignment: .leading, spacing: 12) {
            Text(exercise.name)
                .font(.headline)

            TextField("Write your notes here", text: $exercise.notes, axis: .vertical)
                .lineLimit(3, reservesSpace: true)
                .textFieldStyle(.plain)

            setHeaderRow

            ForEach(exercise.sets.indices, id: \.self) { index in
                HStack(spacing: 12) {
                    Text("\(index + 1)")
                        .frame(width: 30, alignment: .leading)

                    TextField("0", value: $exercise.sets[index].weight, format: .number)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.plain)
                        .frame(width: 110)

                    TextField("0", value: $exercise.sets[index].reps, format: .number)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.plain)
                        .frame(width: 80)
                }
            }

            Button(restLabel) {
                showRestPicker = true
            }
            .font(.subheadline)
            .padding(.vertical, 6)
            .buttonStyle(.borderless)

            Spacer()
                .frame(height: 6)

            Button("Add Set") {
                exercise.sets.append(WorkoutSet())
            }
            .padding(.vertical, 4)
            .buttonStyle(.borderless)
        }
        .sheet(isPresented: $showRestPicker) {
            RestPickerView(restMinutes: $exercise.restMinutes)
        }
    }

    private var restLabel: String {
        guard exercise.restMinutes > 0 else { return "Rest: OFF" }
        let wholeMinutes = Int(exercise.restMinutes)
        let hasHalf = exercise.restMinutes.truncatingRemainder(dividingBy: 1) != 0
        let label = hasHalf ? "\(wholeMinutes).30" : "\(wholeMinutes)"
        return "Rest: \(label) min"
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
    @Binding var restMinutes: Double
    @Environment(\.dismiss) private var dismiss

    private let restOptions = stride(from: 0.0, through: 5.0, by: 0.5).map { $0 }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Rest Timer", selection: $restMinutes) {
                    ForEach(restOptions, id: \.self) { minutes in
                        Text(restLabel(for: minutes))
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

    private func restLabel(for minutes: Double) -> String {
        if minutes == 0 { return "OFF" }
        let wholeMinutes = Int(minutes)
        let hasHalf = minutes.truncatingRemainder(dividingBy: 1) != 0
        return hasHalf ? "\(wholeMinutes).30 min" : "\(wholeMinutes) min"
    }
}

#Preview {
    RoutineDetailView(mode: .create)
        .environmentObject(RoutineStore())
}
