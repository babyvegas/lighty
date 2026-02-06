import SwiftUI

struct AddExerciseCatalogView: View {
    @EnvironmentObject private var store: RoutineStore
    @Environment(\.dismiss) private var dismiss

    var onSelect: (ExerciseCatalogItem) -> Void

    @State private var searchText = ""

    private let popularExercises: [ExerciseCatalogItem] = [
        ExerciseCatalogItem(
            id: "bench_press",
            name: "Barbell Bench Press",
            muscle: "Chest",
            equipment: "Barbell",
            imageURL: nil
        ),
        ExerciseCatalogItem(
            id: "dumbbell_row",
            name: "Dumbbell Row",
            muscle: "Back",
            equipment: "Dumbbell",
            imageURL: nil
        )
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Spacer()
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search exercises", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(Color(white: 0.92))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .frame(maxWidth: 360)
                Spacer()
            }

            HStack(spacing: 12) {
                Button("Muscles") { }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(white: 0.92))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Button("Equipment") { }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(white: 0.92))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            let recent = store.recentExercises
            Text(recent.isEmpty ? "Popular" : "Recent")
                .font(.headline)

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(filteredExercises(from: recent.isEmpty ? popularExercises : recent)) { exercise in
                        Button {
                            store.addRecentExercise(exercise)
                            onSelect(exercise)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                ExerciseIconView(imageURL: exercise.imageURL)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(exercise.name)
                                        .fontWeight(.semibold)
                                    Text("Muscle: \(exercise.muscle)")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                    Text("Equipment: \(exercise.equipment)")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()
                            }
                            .padding()
                            .background(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(white: 0.85), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .background(Color.white)
        .navigationTitle("Add Excercise")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func filteredExercises(from list: [ExerciseCatalogItem]) -> [ExerciseCatalogItem] {
        guard !searchText.isEmpty else { return list }
        return list.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
}

private struct ExerciseIconView: View {
    let imageURL: URL?

    var body: some View {
        Group {
            if let imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Image(systemName: "figure.strengthtraining.traditional")
                            .resizable()
                            .scaledToFit()
                            .padding(10)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Image(systemName: "figure.strengthtraining.traditional")
                    .resizable()
                    .scaledToFit()
                    .padding(10)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 56, height: 56)
        .background(Color(white: 0.95))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    AddExerciseCatalogView { _ in }
        .environmentObject(RoutineStore())
}
