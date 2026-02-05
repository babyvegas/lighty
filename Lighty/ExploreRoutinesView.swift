import SwiftUI

struct ExploreRoutinesView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Explore Routines")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Placeholder screen for curated routines.")
                .foregroundStyle(.secondary)
        }
        .padding()
        .navigationTitle("Explore")
    }
}

#Preview {
    ExploreRoutinesView()
}
