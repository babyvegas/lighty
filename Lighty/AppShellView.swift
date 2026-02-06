import SwiftUI

struct AppShellView: View {
    enum Tab {
        case home
        case training
        case profile
    }

    @State private var selectedTab: Tab = .training

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch selectedTab {
                case .home:
                    HomeLandingView()
                case .training:
                    HomeView()
                case .profile:
                    ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Rectangle()
                .fill(Color(white: 0.88))
                .frame(height: 1)

            HStack(spacing: 0) {
                navItem(title: "Home", icon: "house", tab: .home)
                navItem(title: "Training", icon: "dumbbell", tab: .training)
                navItem(title: "Profile", icon: "person", tab: .profile)
            }
            .padding(.top, 8)
            .padding(.bottom, 10)
            .background(Color.white)
        }
        .background(Color.white)
    }

    private func navItem(title: String, icon: String, tab: Tab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.headline)

                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(selectedTab == tab ? .blue : .black)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
        }
        .buttonStyle(.plain)
    }
}

private struct HomeLandingView: View {
    @EnvironmentObject private var store: RoutineStore

    private var groupedTrainings: [(date: Date, items: [CompletedTraining])] {
        let groups = Dictionary(grouping: store.completedTrainings) {
            Calendar.current.startOfDay(for: $0.date)
        }

        return groups
            .map { ($0.key, $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            if store.completedTrainings.isEmpty {
                VStack(spacing: 14) {
                    Text("No workouts yet")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Your gains are waiting. Tap Training and start your first session.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 56))
                        .foregroundStyle(.blue)
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(groupedTrainings, id: \.date) { section in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(dayLabel(for: section.date))
                                    .font(.headline)

                                ForEach(section.items) { workout in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(workout.title)
                                                .fontWeight(.semibold)
                                            Text("\(workout.exerciseCount) exercises")
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        Text(timeLabel(for: workout.date))
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(12)
                                    .background(Color(white: 0.95))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 18)
                }
                .background(Color.white)
            }
        }
        .background(Color.white)
    }

    private func dayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func timeLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

private struct ProfileView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("Profile")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Profile template")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    AppShellView()
        .environmentObject(RoutineStore())
}
