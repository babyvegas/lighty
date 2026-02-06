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
                .padding(.top, 8)

                List {
                    Section("Routines") {
                        NavigationLink("New Routine") {
                            RoutineDetailView(mode: .create)
                        }
                        .padding(.vertical, 6)

                        NavigationLink("Explore Routines") {
                            ExploreRoutinesView()
                        }
                        .padding(.vertical, 6)
                    }

                    if store.routines.isEmpty {
                        Section {
                            Text("No routines yet")
                                .foregroundStyle(.secondary)
                        }
                    }

                    ForEach(store.routines) { routine in
                        Section {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(routine.name)
                                        .font(.headline)
                                    if !routine.description.isEmpty {
                                        Text(routine.description)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                Menu {
                                    Button("Share Routine (not working yet)") {
                                        // Placeholder
                                    }

                                    Button("Duplicate Routine") {
                                        store.duplicate(routine)
                                    }

                                    NavigationLink("Edit Routine") {
                                        RoutineDetailView(mode: .edit(routine.id))
                                    }

                                    Button(role: .destructive) {
                                        store.delete(routine)
                                    } label: {
                                        Text("Delete Routine")
                                    }
                                } label: {
                                    Image(systemName: "ellipsis")
                                        .imageScale(.large)
                                        .padding(.leading, 8)
                                }
                                .contentShape(Rectangle())
                            }
                            .padding(.vertical, 4)

                            HStack {
                                Spacer()
                                NavigationLink("Start Routine") {
                                    RoutineDetailView(mode: .edit(routine.id))
                                }
                                .buttonStyle(.borderedProminent)
                                Spacer()
                            }
                            .padding(.vertical, 6)
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
