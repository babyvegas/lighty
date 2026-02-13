import SwiftUI

struct AppShellView: View {
    enum Tab {
        case home
        case training
        case profile
    }

    @State private var selectedTab: Tab = .training
    @AppStorage("lighty_preferred_theme") private var preferredTheme: String = "light"
    @EnvironmentObject private var store: RoutineStore
    @StateObject private var workoutSession = WorkoutSessionManager()
    @State private var visibleToast: WorkoutCompletionToast?
    @State private var toastDismissTask: Task<Void, Never>?

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
            .environmentObject(workoutSession)
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 8) {
                if workoutSession.isActive && workoutSession.isMinimized {
                    minimizedWorkoutBar
                        .padding(.horizontal, 12)
                }

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
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .fullScreenCover(isPresented: $workoutSession.isWorkoutPresented) {
            WorkoutSessionView()
                .environmentObject(store)
                .environmentObject(workoutSession)
        }
        .overlay(alignment: .top) {
            if let toast = visibleToast {
                completionToastBanner(toast)
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onChange(of: workoutSession.completionToast) { _, newValue in
            guard let newValue else { return }

            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                visibleToast = newValue
            }

            toastDismissTask?.cancel()
            toastDismissTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(3))
                if Task.isCancelled { return }

                withAnimation(.easeInOut(duration: 0.25)) {
                    visibleToast = nil
                }

                try? await Task.sleep(for: .milliseconds(250))
                if Task.isCancelled { return }
                workoutSession.clearCompletionToast()
            }
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

    private var minimizedWorkoutBar: some View {
        Button {
            workoutSession.restore()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "timer")
                    .foregroundStyle(StyleKit.accentBlue)

                VStack(alignment: .leading, spacing: 2) {
                    Text(workoutSession.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(StyleKit.ink)
                        .lineLimit(1)
                    Text("In progress")
                        .font(.caption)
                        .foregroundStyle(StyleKit.softInk)
                }

                Spacer()

                Text(workoutSession.elapsedLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(StyleKit.accentBlue)

                Image(systemName: "chevron.up")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(StyleKit.accentBlue)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.96))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.9), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 10, y: 5)
        }
        .buttonStyle(.plain)
    }

    private func completionToastBanner(_ toast: WorkoutCompletionToast) -> some View {
        HStack(spacing: 12) {
            Image(systemName: toast.icon)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(0.22))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(toast.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                Text(toast.subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [StyleKit.accentBlue, Color(red: 0.53, green: 0.40, blue: 0.98)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: StyleKit.accentBlue.opacity(0.35), radius: 16, y: 8)
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
        .environmentObject(PhoneWatchConnectivityCoordinator())
}
