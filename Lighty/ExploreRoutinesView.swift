import SwiftUI

struct ExploreRoutinesView: View {
    var body: some View {
        ZStack {
            AppBackgroundLayer()

            VStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.system(size: 48))
                    .foregroundStyle(StyleKit.accentPink)

                Text("Explore Routines")
                    .font(.title2.bold())
                    .foregroundStyle(StyleKit.ink)

                Text("Template: curated plans, favorites, and community picks.")
                    .font(.subheadline)
                    .foregroundStyle(StyleKit.softInk)
                    .multilineTextAlignment(.center)
            }
            .appCard(padding: 22, radius: 22)
            .padding(.horizontal)
        }
        .navigationTitle("Explore")
    }
}

#Preview {
    ExploreRoutinesView()
}
