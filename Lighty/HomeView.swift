import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: RoutineStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    titleBar
                    heroWorkoutButton
                    quickActions

                    HStack {
                        Text("Your Routines")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(StyleKit.ink)
                        Spacer()
                        Text("\(store.routines.count)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(StyleKit.accentBlue)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(StyleKit.accentBlue.opacity(0.12))
                            .clipShape(Capsule())
                    }

                    Group {
                        if store.routines.isEmpty {
                            emptyRoutinesCard
                        } else {
                            VStack(spacing: 14) {
                                ForEach(store.routines) { routine in
                                    routineCard(routine)
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

    private var titleBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Training")
                    .font(.largeTitle.bold())
                    .foregroundStyle(StyleKit.ink)
                Text("A cute place for serious gains")
                    .font(.subheadline)
                    .foregroundStyle(StyleKit.softInk)
            }

            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            colors: [StyleKit.accentMint.opacity(0.32), StyleKit.accentPink.opacity(0.30)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)

                Image(systemName: "sparkles")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(StyleKit.accentBlue)
            }
        }
    }

    private var heroWorkoutButton: some View {
        NavigationLink {
            EmptyWorkoutView()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Color.white.opacity(0.22))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.white.opacity(0.9))
                }

                Text("New Empty Workout")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)

                Text("Start quick, add exercises, and track your set flow.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                LinearGradient(
                    colors: [StyleKit.accentBlue, Color(red: 0.50, green: 0.42, blue: 0.98)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: StyleKit.accentBlue.opacity(0.24), radius: 14, y: 8)
        }
        .buttonStyle(.plain)
    }

    private var quickActions: some View {
        HStack(spacing: 12) {
            NavigationLink {
                RoutineDetailView(mode: .create)
            } label: {
                QuickActionTile(
                    title: "New Routine",
                    subtitle: "Plan your session",
                    icon: "book.closed.fill",
                    tint: StyleKit.accentMint
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                ExploreRoutinesView()
            } label: {
                QuickActionTile(
                    title: "Explore",
                    subtitle: "Find ideas",
                    icon: "sparkle.magnifyingglass",
                    tint: StyleKit.accentPeach
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var emptyRoutinesCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray.fill")
                .font(.title2)
                .foregroundStyle(StyleKit.accentBlue.opacity(0.9))

            Text("No routines yet")
                .font(.headline.weight(.semibold))
                .foregroundStyle(StyleKit.ink)

            Text("Create one and keep your favorite workouts ready.")
                .font(.subheadline)
                .foregroundStyle(StyleKit.softInk)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .appCard(padding: 14, radius: 18)
    }

    private func routineCard(_ routine: Routine) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(routine.name)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(StyleKit.ink)

                    if !routine.description.isEmpty {
                        Text(routine.description)
                            .font(.subheadline)
                            .foregroundStyle(StyleKit.softInk)
                    }
                }

                Spacer()

                Menu {
                    Button("Share Routine (not working yet)") { }

                    Button("Duplicate Routine") {
                        store.duplicate(routine)
                    }

                    NavigationLink("Edit Routine") {
                        EditRoutineView(routineID: routine.id)
                    }

                    Button(role: .destructive) {
                        store.delete(routine)
                    } label: {
                        Text("Delete Routine")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(StyleKit.ink)
                        .frame(width: 28, height: 28)
                        .background(StyleKit.softChip.opacity(0.9))
                        .clipShape(Circle())
                }
            }

            NavigationLink {
                RoutineDetailView(mode: .edit(routine.id))
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.circle.fill")
                    Text("Start Routine")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(SoftFillButtonStyle())
        }
        .appCard(padding: 15, radius: 18)
    }
}

private struct QuickActionTile: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(StyleKit.ink)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.33))
                .clipShape(RoundedRectangle(cornerRadius: 9))

            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(StyleKit.ink)
                .lineLimit(1)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(StyleKit.softInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.95), tint.opacity(0.16)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.9), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 4)
    }
}

#Preview {
    HomeView()
        .environmentObject(RoutineStore())
}
