import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: RoutineStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    NavigationLink {
                        EmptyWorkoutView()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.white)
                            Text("New Empty Workout")
                            Spacer()
                        }
                    }
                    .buttonStyle(PrimaryFillButtonStyle())

                    HStack {
                        Text("Routines")
                            .font(.title3.bold())
                            .foregroundStyle(StyleKit.ink)
                        Spacer()
                        Text("\(store.routines.count)")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(StyleKit.accentBlue)
                    }

                    HStack(spacing: 12) {
                        NavigationLink {
                            RoutineDetailView(mode: .create)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "book.fill")
                                Text("New Routine")
                            }
                        }
                        .buttonStyle(SoftFillButtonStyle())

                        NavigationLink {
                            ExploreRoutinesView()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                Text("Explore")
                            }
                        }
                        .buttonStyle(SoftFillButtonStyle())
                    }

                    if store.routines.isEmpty {
                        emptyRoutinesCard
                    }

                    ForEach(store.routines) { routine in
                        routineCard(routine)
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
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Training")
                    .font(.largeTitle.bold())
                    .foregroundStyle(StyleKit.ink)
                Text("Build your strongest week")
                    .font(.subheadline)
                    .foregroundStyle(StyleKit.softInk)
            }

            Spacer()

            ZStack {
                Circle()
                    .fill(StyleKit.accentBlue.opacity(0.2))
                    .frame(width: 58, height: 58)
                Image(systemName: "dumbbell.fill")
                    .font(.title2)
                    .foregroundStyle(StyleKit.accentBlue)
            }
        }
        .appCard(padding: 16, radius: 20)
    }

    private var emptyRoutinesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No routines yet")
                .font(.headline)
                .foregroundStyle(StyleKit.ink)
            Text("Create one and keep your favorite workouts ready.")
                .font(.subheadline)
                .foregroundStyle(StyleKit.softInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard(padding: 14, radius: 16)
    }

    private func routineCard(_ routine: Routine) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(routine.name)
                        .font(.headline)
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
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.title3)
                        .foregroundStyle(StyleKit.softInk)
                }
            }

            NavigationLink {
                RoutineDetailView(mode: .edit(routine.id))
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start Routine")
                }
            }
            .buttonStyle(SoftFillButtonStyle())
        }
        .appCard(padding: 14, radius: 18)
    }
}

#Preview {
    HomeView()
        .environmentObject(RoutineStore())
}
