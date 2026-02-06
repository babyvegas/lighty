import SwiftUI

struct EditRoutineView: View {
    let routineID: Routine.ID

    @EnvironmentObject private var store: RoutineStore
    @Environment(\.dismiss) private var dismiss

    @State private var routine: Routine = Routine()
    @State private var showExercisePicker = false
    @State private var showReorderSheet = false
    @State private var exerciseToReplace: ExerciseEntry.ID?
    @State private var showRestPicker = false
    @State private var restExerciseID: ExerciseEntry.ID?

    var body: some View {
        VStack(spacing: 0) {
            headerBar
                .padding(.horizontal)
                .padding(.top, 10)
                .padding(.bottom, 6)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TextField("", text: $routine.name, prompt: Text("New Routine"))
                        .font(.title2)
                        .fontWeight(.bold)
                        .textFieldStyle(.plain)

                    if !routine.description.isEmpty {
                        Text(routine.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    ForEach($routine.exercises) { $exercise in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                HStack(spacing: 8) {
                                    Image(systemName: "dumbbell")
                                        .font(.subheadline)
                                    Text(exercise.name)
                                        .font(.headline)
                                }
                                .foregroundStyle(.blue)

                                Spacer()

                                Menu {
                                    Button("Re-organize") {
                                        showReorderSheet = true
                                    }

                                    Button("Replace excercise") {
                                        exerciseToReplace = exercise.id
                                        showExercisePicker = true
                                    }

                                    Button(role: .destructive) {
                                        deleteExercise(exercise)
                                    } label: {
                                        Text("Delete excercise")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis")
                                        .foregroundStyle(.black)
                                }
                            }

                            TextField("Write your notes here", text: $exercise.notes, axis: .vertical)
                                .lineLimit(3, reservesSpace: true)
                                .textFieldStyle(.plain)

                            Button(restLabel(for: exercise)) {
                                restExerciseID = exercise.id
                                showRestPicker = true
                            }
                            .font(.subheadline)
                            .padding(.vertical, 6)
                            .buttonStyle(.borderless)

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
                                .padding(.vertical, 6)
                                .padding(.horizontal, 6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(index.isMultiple(of: 2) ? Color.white : Color(white: 0.95))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }

                            Spacer()
                                .frame(height: 6)

                            Button {
                                exercise.sets.append(WorkoutSet())
                            } label: {
                                Text("+ Add Set")
                                    .fontWeight(.semibold)
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color(white: 0.92))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .padding(.vertical, 8)
                    }

                    Button("Add excercise") {
                        showExercisePicker = true
                    }
                    .padding(.vertical, 6)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .background(Color.white)
        }
        .background(Color.white)
        .navigationBarHidden(true)
        .onAppear {
            if let existing = store.routine(with: routineID) {
                routine = existing
            }
        }
        .sheet(isPresented: $showExercisePicker) {
            ExercisePickerView { selectedName in
                if let replaceID = exerciseToReplace,
                   let index = routine.exercises.firstIndex(where: { $0.id == replaceID }) {
                    routine.exercises[index].name = selectedName
                } else {
                    routine.exercises.append(ExerciseEntry(name: selectedName))
                }
                exerciseToReplace = nil
                showExercisePicker = false
            }
        }
        .sheet(isPresented: $showReorderSheet) {
            ReorderExercisesView(exercises: $routine.exercises)
        }
        .sheet(isPresented: $showRestPicker) {
            if let binding = restBinding() {
                RestPickerView(restMinutes: binding)
            }
        }
    }

    private var headerBar: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .foregroundStyle(.blue)

            Spacer()

            Text("Edit Routine")
                .fontWeight(.semibold)

            Spacer()

            Button("Update") {
                store.save(routine)
                dismiss()
            }
            .foregroundStyle(.blue)
        }
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

    private func deleteExercise(_ exercise: ExerciseEntry) {
        routine.exercises.removeAll { $0.id == exercise.id }
    }

    private func restLabel(for exercise: ExerciseEntry) -> String {
        guard exercise.restMinutes > 0 else { return "Rest: OFF" }
        let wholeMinutes = Int(exercise.restMinutes)
        let hasHalf = exercise.restMinutes.truncatingRemainder(dividingBy: 1) != 0
        let label = hasHalf ? "\(wholeMinutes).30" : "\(wholeMinutes)"
        return "Rest: \(label) min"
    }

    private func restBinding() -> Binding<Double>? {
        guard let id = restExerciseID,
              let index = routine.exercises.firstIndex(where: { $0.id == id }) else {
            return nil
        }

        return Binding(
            get: { routine.exercises[index].restMinutes },
            set: { routine.exercises[index].restMinutes = $0 }
        )
    }
}

private struct ReorderExercisesView: View {
    @Binding var exercises: [ExerciseEntry]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(exercises) { exercise in
                    HStack(spacing: 8) {
                        Image(systemName: "line.3.horizontal")
                            .foregroundStyle(.secondary)
                        Text(exercise.name)
                    }
                }
                .onMove(perform: move)
            }
            .scrollContentBackground(.hidden)
            .background(Color.white)
            .navigationTitle("Re-organize")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .environment(\.editMode, .constant(.active))
    }

    private func move(from source: IndexSet, to destination: Int) {
        exercises.move(fromOffsets: source, toOffset: destination)
    }
}

#Preview {
    EditRoutineView(routineID: Routine.ID())
        .environmentObject(RoutineStore())
}
