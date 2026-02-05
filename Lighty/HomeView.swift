import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: RoutineStore

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                NavigationLink("New Empty Workout") {
                    EmptyWorkoutView()
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)

                List {
                    Section("Routines") {
                        NavigationLink("New Routine") {
                            RoutineDetailView(mode: .create)
                        }

                        NavigationLink("Explore Routines") {
                            ExploreRoutinesView()
                        }

                        if store.routines.isEmpty {
                            Text("No routines yet")
                                .foregroundStyle(.secondary)
                        }

                        ForEach(store.routines) { routine in
                            NavigationLink {
                                RoutineDetailView(mode: .edit(routine.id))
                            } label: {
                                HStack {
                                    Text(routine.name)
                                    Spacer()
                                    Text("Start")
                                        .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("Training")
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(RoutineStore())
}
