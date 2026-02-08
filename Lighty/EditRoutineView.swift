import SwiftUI

struct EditRoutineView: View {
    let routineID: Routine.ID

    @EnvironmentObject private var store: RoutineStore
    @Environment(\.dismiss) private var dismiss

    @State private var routine: Routine = Routine()
    @State private var showExercisePicker = false
    @State private var showReorderSheet = false
    @State private var exerciseToReplace: ExerciseEntry.ID?
    @State private var restExerciseID: ExerciseEntry.ID?
    @State private var selectedExerciseID: ExerciseEntry.ID?

    var body: some View {
        VStack(spacing: 0) {
            headerBar
                .padding(.horizontal)
                .padding(.top, 10)
                .padding(.bottom, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TextField("New Routine", text: $routine.name)
                        .font(.title2.bold())
                        .foregroundStyle(StyleKit.ink)
                        .appCard(padding: 14, radius: 16)

                    ForEach($routine.exercises) { $exercise in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Button {
                                    selectedExerciseID = exercise.id
                                } label: {
                                    HStack(spacing: 8) {
                                        ExerciseRowThumbnail(imageURL: exercise.imageURL)
                                        Text(exercise.name)
                                            .font(.headline)
                                            .foregroundStyle(StyleKit.accentBlue)
                                    }
                                }
                                .buttonStyle(.plain)

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
                                    Image(systemName: "ellipsis.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(StyleKit.softInk)
                                }
                            }

                            TextField("Write your notes here", text: $exercise.notes, axis: .vertical)
                                .lineLimit(3, reservesSpace: true)
                                .padding(10)
                                .background(StyleKit.softChip.opacity(0.75))
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                            Button(restLabel(for: exercise)) {
                                restExerciseID = exercise.id
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(StyleKit.accentBlue)
                            .font(.subheadline.weight(.semibold))

                            setHeaderRow

                            ForEach(exercise.sets.indices, id: \.self) { index in
                                HStack(spacing: 12) {
                                    Text("\(index + 1)")
                                        .frame(width: 30, alignment: .leading)
                                        .foregroundStyle(StyleKit.softInk)

                                    TextField(
                                        "0",
                                        value: $exercise.sets[index].weight,
                                        format: .number.precision(.fractionLength(0...1))
                                    )
                                        .keyboardType(.decimalPad)
                                        .textFieldStyle(.plain)
                                        .frame(width: 110)

                                    TextField("0", value: $exercise.sets[index].reps, format: .number)
                                        .keyboardType(.numberPad)
                                        .textFieldStyle(.plain)
                                        .frame(width: 80)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 10)
                                .background(index.isMultiple(of: 2) ? Color.white.opacity(0.42) : StyleKit.softChip.opacity(0.75))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }

                            Button {
                                exercise.sets.append(WorkoutSet())
                            } label: {
                                HStack {
                                    Image(systemName: "plus")
                                    Text("Add Set")
                                }
                            }
                            .buttonStyle(SoftFillButtonStyle())
                        }
                        .appCard(padding: 14, radius: 16)
                    }

                    Button {
                        showExercisePicker = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add excercise")
                            Spacer()
                        }
                    }
                    .buttonStyle(SoftFillButtonStyle())
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
            .background(Color.clear)
        }
        .background(Color.clear)
        .navigationBarHidden(true)
        .onAppear {
            if let existing = store.routine(with: routineID) {
                routine = existing
            }
        }
        .sheet(isPresented: $showExercisePicker) {
            AddExerciseCatalogView { selected in
                if let replaceID = exerciseToReplace,
                   let index = routine.exercises.firstIndex(where: { $0.id == replaceID }) {
                    routine.exercises[index].name = selected.name
                    routine.exercises[index].imageURL = selected.imageURL
                    routine.exercises[index].mediaURL = selected.mediaURL
                    routine.exercises[index].primaryMuscle = selected.primaryMuscle
                    routine.exercises[index].secondaryMuscles = selected.secondaryMuscles
                } else {
                    routine.exercises.append(
                        ExerciseEntry(
                            name: selected.name,
                            imageURL: selected.imageURL,
                            mediaURL: selected.mediaURL,
                            primaryMuscle: selected.primaryMuscle,
                            secondaryMuscles: selected.secondaryMuscles
                        )
                    )
                }
                exerciseToReplace = nil
                showExercisePicker = false
            }
        }
        .sheet(isPresented: $showReorderSheet) {
            ReorderExercisesView(exercises: $routine.exercises)
        }
        .sheet(
            isPresented: Binding(
                get: { restExerciseID != nil },
                set: { if !$0 { restExerciseID = nil } }
            )
        ) {
            if let binding = restBinding() {
                RestPickerView(restMinutes: binding)
            }
        }
        .sheet(
            isPresented: Binding(
                get: { selectedExerciseID != nil },
                set: { if !$0 { selectedExerciseID = nil } }
            )
        ) {
            if let id = selectedExerciseID,
               let binding = exerciseBinding(for: id) {
                ExerciseInsightsView(exercise: binding)
            }
        }
    }

    private var headerBar: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .foregroundStyle(StyleKit.accentBlue)

            Spacer()

            Text("Edit Routine")
                .fontWeight(.semibold)
                .foregroundStyle(StyleKit.ink)

            Spacer()

            Button("Update") {
                store.save(routine)
                dismiss()
            }
            .foregroundStyle(StyleKit.accentBlue)
        }
    }

    private var setHeaderRow: some View {
        HStack(spacing: 12) {
            Text("Set")
                .font(.caption.weight(.semibold))
                .foregroundStyle(StyleKit.softInk)
                .frame(width: 30, alignment: .leading)

            Text("Weight (LBS)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(StyleKit.softInk)
                .frame(width: 110, alignment: .leading)

            Text("Reps")
                .font(.caption.weight(.semibold))
                .foregroundStyle(StyleKit.softInk)
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

    private func exerciseBinding(for id: ExerciseEntry.ID) -> Binding<ExerciseEntry>? {
        guard let index = routine.exercises.firstIndex(where: { $0.id == id }) else {
            return nil
        }

        return Binding(
            get: { routine.exercises[index] },
            set: { routine.exercises[index] = $0 }
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
                            .foregroundStyle(StyleKit.softInk)
                        Text(exercise.name)
                            .foregroundStyle(StyleKit.ink)
                    }
                }
                .onMove(perform: move)
            }
            .scrollContentBackground(.hidden)
            .background(AppBackgroundLayer())
            .navigationTitle("Re-organize")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(StyleKit.accentBlue)
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
