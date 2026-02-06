import SwiftUI

struct AppShellView: View {
    enum Tab {
        case home
        case training
        case profile
    }

    @State private var selectedTab: Tab = .training
    @AppStorage("lighty_preferred_theme") private var preferredTheme: String = "light"

    var body: some View {
        ZStack {
            AppBackgroundLayer()

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
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.white.opacity(0.75))
                    .frame(height: 1)

                HStack(spacing: 0) {
                    navItem(title: "Home", icon: "house.fill", tab: .home)
                    navItem(title: "Training", icon: "dumbbell.fill", tab: .training)
                    navItem(title: "Profile", icon: "person.crop.circle", tab: .profile)
                }
                .padding(.top, 6)
                .frame(height: 72)
                .background(Color.white.opacity(0.95))
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .preferredColorScheme(preferredTheme == "dark" ? .dark : .light)
    }

    private func navItem(title: String, icon: String, tab: Tab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.headline)
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(selectedTab == tab ? StyleKit.accentBlue : StyleKit.softInk)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
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
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    if store.completedTrainings.isEmpty {
                        emptyState
                    } else {
                        ForEach(groupedTrainings, id: \.date) { section in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(dayLabel(for: section.date))
                                    .font(.headline)
                                    .foregroundStyle(StyleKit.ink)

                                ForEach(section.items) { workout in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(workout.title)
                                                .fontWeight(.semibold)
                                                .foregroundStyle(StyleKit.ink)
                                            Text("\(workout.exerciseCount) exercises")
                                                .font(.footnote)
                                                .foregroundStyle(StyleKit.softInk)
                                        }

                                        Spacer()

                                        Text(timeLabel(for: workout.date))
                                            .font(.footnote)
                                            .foregroundStyle(StyleKit.softInk)
                                    }
                                    .appCard()
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
            .background(Color.clear)
            .navigationBarHidden(true)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Home")
                        .font(.largeTitle.bold())
                        .foregroundStyle(StyleKit.ink)
                    Text("Your workout timeline")
                        .font(.subheadline)
                        .foregroundStyle(StyleKit.softInk)
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(StyleKit.accentMint.opacity(0.25))
                        .frame(width: 54, height: 54)
                    Image(systemName: "calendar")
                        .font(.title3)
                        .foregroundStyle(StyleKit.accentBlue)
                }
            }

            Text("Sessions done: \(store.completedTrainings.count)")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(StyleKit.accentBlue)
        }
        .appCard(padding: 16, radius: 20)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Text("No workouts yet")
                .font(.title3.bold())
                .foregroundStyle(StyleKit.ink)

            Text("Your gains are waiting. Start your first workout and we will track it here.")
                .font(.subheadline)
                .foregroundStyle(StyleKit.softInk)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)

            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                Image(systemName: "figure.strengthtraining.traditional")
                Image(systemName: "heart.fill")
            }
            .font(.title3)
            .foregroundStyle(StyleKit.accentPink)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .appCard(padding: 16, radius: 22)
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
    @EnvironmentObject private var store: RoutineStore
    @AppStorage("lighty_preferred_theme") private var preferredTheme: String = "light"

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Profile")
                    .font(.largeTitle.bold())
                    .foregroundStyle(StyleKit.ink)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Local athlete mode")
                        .font(.headline)
                        .foregroundStyle(StyleKit.ink)
                    Text("No account needed. Your data lives on this device.")
                        .foregroundStyle(StyleKit.softInk)
                }
                .appCard(padding: 16, radius: 18)

                HStack(spacing: 12) {
                    statCard(title: "Routines", value: "\(store.routines.count)", icon: "book.closed.fill")
                    statCard(title: "Sessions", value: "\(store.completedTrainings.count)", icon: "figure.strengthtraining.traditional")
                }

                Button {
                    preferredTheme = preferredTheme == "dark" ? "light" : "dark"
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: preferredTheme == "dark" ? "sun.max.fill" : "moon.fill")
                        Text(preferredTheme == "dark" ? "Switch to Light Mode" : "Switch to Dark Mode")
                        Spacer()
                    }
                }
                .buttonStyle(SoftFillButtonStyle())

                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 120)
            .navigationBarHidden(true)
            .background(Color.clear)
        }
    }

    private func statCard(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(StyleKit.accentBlue)
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(StyleKit.ink)
            Text(title)
                .font(.footnote)
                .foregroundStyle(StyleKit.softInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard(padding: 14, radius: 16)
    }
}

#Preview {
    AppShellView()
        .environmentObject(RoutineStore())
}
