import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: RoutineStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Training")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    NavigationLink {
                        EmptyWorkoutView()
                    } label: {
                        HStack(spacing: 8) {
                            Text("+")
                                .fontWeight(.bold)
                            Text("New Empty Workout")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(white: 0.92))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)

                    Text("Routines")
                        .font(.title3)
                        .fontWeight(.bold)

                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            NavigationLink {
                                RoutineDetailView(mode: .create)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "book")
                                    Text("New Routine")
                                        .fontWeight(.semibold)
                                    Spacer()
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color(white: 0.92))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)

                            NavigationLink {
                                ExploreRoutinesView()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "magnifyingglass")
                                    Text("Explore")
                                        .fontWeight(.semibold)
                                    Spacer()
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color(white: 0.92))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }

                        if store.routines.isEmpty {
                            Text("No routines yet")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        ForEach(store.routines) { routine in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(routine.name)
                                            .fontWeight(.bold)
                                        if !routine.description.isEmpty {
                                            Text(routine.description)
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
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
                                            .foregroundStyle(.black)
                                            .imageScale(.large)
                                    }
                                }

                                HStack {
                                    Spacer()
                                    NavigationLink("Start Routine") {
                                        RoutineDetailView(mode: .edit(routine.id))
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 18)
                                    .background(Color(white: 0.92))
                                    .clipShape(Capsule())
                                    Spacer()
                                }
                            }
                            .padding()
                            .background(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(white: 0.85), lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .background(Color.white)
            .navigationTitle("Training")
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(RoutineStore())
}
