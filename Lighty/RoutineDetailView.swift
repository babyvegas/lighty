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
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                routineHeader

                HStack {
                    Text("Exercises")
                        .font(.title3.bold())
                        .foregroundStyle(StyleKit.ink)
                    Spacer()
                    Text("\(routine.exercises.count)")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(StyleKit.accentBlue)
                }

                if routine.exercises.isEmpty {
                    Text("No exercises yet. Add your first one below.")
                        .font(.subheadline)
                        .foregroundStyle(StyleKit.softInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .appCard(padding: 14, radius: 14)
                }

                ForEach($routine.exercises) { $exercise in
                    ExerciseEditorView(exercise: $exercise)
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
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 120)
        }
        .scrollIndicators(.hidden)
        .background(Color.clear)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    saveRoutine()
                }
                .foregroundStyle(StyleKit.accentBlue)
            }
        }
        .sheet(isPresented: $showExercisePicker) {
            AddExerciseCatalogView { selected in
                addExercise(from: selected)
                showExercisePicker = false
            }
        }
        .onAppear {
            if case .edit(let id) = mode, let existing = store.routine(with: id) {
                routine = existing
            }
        }
    }

    private var routineHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("New Routine", text: $routine.name)
                .font(.title2.bold())
                .foregroundStyle(StyleKit.ink)

            TextField("Routine description", text: $routine.description, axis: .vertical)
                .lineLimit(3, reservesSpace: true)
                .foregroundStyle(StyleKit.softInk)
        }
        .appCard(padding: 16, radius: 20)
    }

    private func addExercise(from catalog: ExerciseCatalogItem) {
        routine.exercises.append(
            ExerciseEntry(
                name: catalog.name,
                imageURL: catalog.imageURL,
                mediaURL: catalog.mediaURL,
                primaryMuscle: catalog.primaryMuscle,
                secondaryMuscles: catalog.secondaryMuscles
            )
        )
    }

    private func saveRoutine() {
        store.save(routine)
        if case .edit = mode {
            store.recordTraining(from: routine)
        }
        dismiss()
    }
}

private struct ExerciseEditorView: View {
    @Binding var exercise: ExerciseEntry
    @State private var showRestPicker = false
    @State private var showInsights = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                showInsights = true
            } label: {
                HStack(spacing: 8) {
                    ExerciseRowThumbnail(imageURL: exercise.imageURL)
                    Text(exercise.name)
                        .font(.headline)
                        .foregroundStyle(StyleKit.accentBlue)
                }
            }
            .buttonStyle(.plain)

            TextField("Write your notes here", text: $exercise.notes, axis: .vertical)
                .lineLimit(3, reservesSpace: true)
                .padding(10)
                .background(StyleKit.softChip.opacity(0.75))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Button(restLabel) {
                showRestPicker = true
            }
            .buttonStyle(.plain)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(StyleKit.accentBlue)
            .padding(.vertical, 4)

            setHeaderRow

            ForEach(exercise.sets.indices, id: \.self) { index in
                HStack(spacing: 12) {
                    Text("\(index + 1)")
                        .frame(width: 30, alignment: .leading)
                        .foregroundStyle(StyleKit.softInk)

                    TextField("0", value: $exercise.sets[index].weight, format: .number)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.plain)
                        .frame(width: 110)

                    TextField("0", value: $exercise.sets[index].reps, format: .number)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.plain)
                        .frame(width: 80)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
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
        .sheet(isPresented: $showRestPicker) {
            RestPickerView(restMinutes: $exercise.restMinutes)
        }
        .sheet(isPresented: $showInsights) {
            ExerciseInsightsView(exercise: $exercise)
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
}

struct RestPickerView: View {
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
            .scrollContentBackground(.hidden)
            .background(AppBackgroundLayer())
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(StyleKit.accentBlue)
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
