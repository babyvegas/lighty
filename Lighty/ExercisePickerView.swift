import SwiftUI

struct ExercisePickerView: View {
    var onSelect: (String) -> Void

    private let exercises = [
        "Barbell Bench Press",
        "Dumbbell Row"
    ]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(exercises, id: \.self) { exercise in
                    Button(exercise) {
                        onSelect(exercise)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Add Exercise")
            .scrollContentBackground(.hidden)
            .background(Color.white)
        }
    }
}

#Preview {
    ExercisePickerView { _ in }
}
