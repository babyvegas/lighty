import SwiftUI

struct EmptyWorkoutView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("New Empty Workout")
                .font(.title2)
                .fontWeight(.semibold)
            Text("This is a placeholder for an empty workout flow.")
                .foregroundStyle(.secondary)
        }
        .padding()
        .navigationTitle("Workout")
    }
}

#Preview {
    EmptyWorkoutView()
}
