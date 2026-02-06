import SwiftUI

struct EmptyWorkoutView: View {
    var body: some View {
        ZStack {
            AppBackgroundLayer()

            VStack(spacing: 14) {
                Image(systemName: "bolt.heart.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(StyleKit.accentBlue)

                Text("New Empty Workout")
                    .font(.title2.bold())
                    .foregroundStyle(StyleKit.ink)

                Text("Quick-start mode. Add exercises and go train.")
                    .font(.subheadline)
                    .foregroundStyle(StyleKit.softInk)
                    .multilineTextAlignment(.center)
            }
            .appCard(padding: 22, radius: 22)
            .padding(.horizontal)
        }
        .navigationTitle("Workout")
    }
}

#Preview {
    EmptyWorkoutView()
}
