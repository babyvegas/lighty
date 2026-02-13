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
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Label(dayLabel(for: section.date), systemImage: "calendar")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(StyleKit.ink)

                                    Spacer()

                                    Text(sessionCountLabel(section.items.count))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(StyleKit.accentBlue)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(StyleKit.softChip.opacity(0.72))
                                .clipShape(Capsule())

                                ForEach(section.items) { workout in
                                    trainingCard(workout)
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
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(greetingTitle)
                        .font(.title2.bold())
                        .foregroundStyle(StyleKit.ink)
                    Text("Tu timeline de entrenamientos")
                        .font(.subheadline)
                        .foregroundStyle(StyleKit.softInk)
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(StyleKit.accentMint.opacity(0.32))
                        .frame(width: 58, height: 58)
                    Circle()
                        .fill(StyleKit.accentPink.opacity(0.26))
                        .frame(width: 42, height: 42)
                        .offset(x: -8, y: -8)
                    Image(systemName: "figure.run.circle.fill")
                        .font(.title2)
                        .foregroundStyle(StyleKit.accentBlue)
                }
            }

            HStack(spacing: 8) {
                topStatChip(title: "Sesiones", value: "\(store.completedTrainings.count)")
                topStatChip(title: "Semana", value: "\(weeklySessions)")
                topStatChip(title: "Min", value: "\(totalTrackedMinutes)")
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.95),
                    StyleKit.accentMint.opacity(0.16),
                    StyleKit.accentPink.opacity(0.14)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.92), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: Color.black.opacity(0.05), radius: 12, y: 6)
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

    private func trainingCard(_ workout: CompletedTraining) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.title)
                        .font(.headline.bold())
                        .foregroundStyle(StyleKit.ink)
                        .lineLimit(2)
                    Text("\(workout.exerciseCount) ejercicios")
                        .font(.caption)
                        .foregroundStyle(StyleKit.softInk)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 5) {
                    Text(timeLabel(for: workout.date))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(StyleKit.softInk)
                    Image(systemName: "clock.badge.checkmark.fill")
                        .font(.caption)
                        .foregroundStyle(StyleKit.accentBlue.opacity(0.9))
                }
            }

            HStack(spacing: 8) {
                metricChip(title: "Tiempo", value: durationLabel(workout.durationSeconds), tint: StyleKit.accentMint)
                metricChip(title: "Volumen", value: volumeLabel(workout.volume), tint: StyleKit.accentBlue)
                metricChip(title: "Récords", value: recordsLabel(workout.recordsCount))
                metricChip(title: "Media LPM", value: "—")
            }

            VStack(alignment: .leading, spacing: 8) {
                if workout.exerciseSummaries.isEmpty {
                    Text("\(workout.exerciseCount) ejercicios")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(StyleKit.softInk)
                } else {
                    ForEach(Array(workout.exerciseSummaries.prefix(3))) { exercise in
                        HStack(spacing: 10) {
                            ExerciseRowThumbnail(imageURL: exercise.imageURL)
                            Text(seriesLabel(for: exercise))
                                .font(.subheadline)
                                .foregroundStyle(StyleKit.ink)
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.64))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }

            if !workout.exerciseSummaries.isEmpty {
                NavigationLink {
                    CompletedTrainingExercisesView(training: workout)
                } label: {
                    HStack(spacing: 6) {
                        Spacer()
                        Text("Ver más ejercicios")
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                        Spacer()
                    }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(StyleKit.softInk)
                        .padding(.top, 2)
                }
                .buttonStyle(.plain)
            }
        }
        .appCard(padding: 14, radius: 16)
    }

    private func metricChip(title: String, value: String, tint: Color = StyleKit.softChip) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(StyleKit.softInk)
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(StyleKit.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(tint.opacity(0.18))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func topStatChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(StyleKit.softInk)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(StyleKit.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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

    private func durationLabel(_ seconds: Int) -> String {
        guard seconds > 0 else { return "0m" }
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private func volumeLabel(_ volume: Double) -> String {
        let rounded = Int(volume.rounded())
        return "\(rounded) lbs"
    }

    private func seriesLabel(for exercise: CompletedTrainingExerciseSummary) -> String {
        let word = exercise.setCount == 1 ? "serie" : "series"
        return "\(exercise.setCount) \(word) \(exercise.name)"
    }

    private func recordsLabel(_ records: Int?) -> String {
        guard let records, records > 0 else { return "—" }
        return "\(records)"
    }

    private var greetingTitle: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12:
            return "Buenos días"
        case 12..<19:
            return "Buenas tardes"
        default:
            return "Buenas noches"
        }
    }

    private var weeklySessions: Int {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .distantPast
        return store.completedTrainings.filter { $0.date >= startOfWeek }.count
    }

    private var totalTrackedMinutes: Int {
        let totalSeconds = store.completedTrainings.reduce(0) { $0 + max(0, $1.durationSeconds) }
        return totalSeconds / 60
    }

    private func sessionCountLabel(_ count: Int) -> String {
        let word = count == 1 ? "sesión" : "sesiones"
        return "\(count) \(word)"
    }
}

private struct CompletedTrainingExercisesView: View {
    let training: CompletedTraining

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(training.exerciseSummaries) { exercise in
                    HStack(spacing: 10) {
                        ExerciseRowThumbnail(imageURL: exercise.imageURL)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(exercise.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(StyleKit.ink)
                                .lineLimit(2)
                            Text(seriesLabel(exercise))
                                .font(.caption)
                                .foregroundStyle(StyleKit.softInk)
                        }
                        Spacer()
                    }
                    .appCard(padding: 12, radius: 14)
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(Color.clear)
        .navigationTitle("Ejercicios")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func seriesLabel(_ exercise: CompletedTrainingExerciseSummary) -> String {
        let word = exercise.setCount == 1 ? "serie" : "series"
        return "\(exercise.setCount) \(word)"
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
