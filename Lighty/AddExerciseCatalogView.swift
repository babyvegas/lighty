import SwiftUI
internal import Combine

private extension URL {
    func appending(queryItems: [URLQueryItem]) -> URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return self
        }
        components.queryItems = (components.queryItems ?? []) + queryItems
        return components.url ?? self
    }
}

struct AddExerciseCatalogView: View {
    @EnvironmentObject private var store: RoutineStore
    @Environment(\.dismiss) private var dismiss

    var onSelect: (ExerciseCatalogItem) -> Void

    @State private var searchText = ""
    @StateObject private var viewModel = ExerciseCatalogViewModel()
    @State private var showMusclePicker = false
    @State private var showEquipmentPicker = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundLayer()

                VStack(alignment: .leading, spacing: 16) {
                    searchBar

                    HStack(spacing: 12) {
                        Button {
                            showMusclePicker = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "bolt.heart")
                                Text("Muscles")
                            }
                        }
                        .buttonStyle(SoftFillButtonStyle())

                        Button {
                            showEquipmentPicker = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "dumbbell.fill")
                                Text("Equipment")
                            }
                        }
                        .buttonStyle(SoftFillButtonStyle())
                    }

                    let recent = store.recentExercises
                    Text(viewModel.sectionTitle(recentIsEmpty: recent.isEmpty))
                        .font(.headline)
                        .foregroundStyle(StyleKit.ink)

                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(displayedExercises(recent: recent)) { exercise in
                                Button {
                                    store.addRecentExercise(exercise)
                                    onSelect(exercise)
                                    dismiss()
                                } label: {
                                    HStack(spacing: 12) {
                                        ExerciseIconView(imageURL: exercise.imageURL)

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(exercise.name)
                                                .fontWeight(.semibold)
                                                .foregroundStyle(StyleKit.ink)

                                            Text("Muscle: \(exercise.muscle)")
                                                .font(.footnote)
                                                .foregroundStyle(StyleKit.softInk)

                                            Text("Equipment: \(exercise.equipment)")
                                                .font(.footnote)
                                                .foregroundStyle(StyleKit.softInk)
                                        }

                                        Spacer()
                                    }
                                    .appCard(padding: 12, radius: 14)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.bottom, 24)
                    }
                    .scrollIndicators(.hidden)
                    .overlay {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(StyleKit.accentBlue)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            await viewModel.loadPopular()
        }
        .onChange(of: searchText) { _, newValue in
            Task { await viewModel.search(text: newValue) }
        }
        .sheet(isPresented: $showMusclePicker) {
            CategoryPickerView(title: "Muscles", items: viewModel.bodyParts) { selection in
                Task { await viewModel.filterByBodyPart(selection) }
            }
            .task { await viewModel.loadBodyParts() }
        }
        .sheet(isPresented: $showEquipmentPicker) {
            CategoryPickerView(title: "Equipment", items: viewModel.equipment) { selection in
                Task { await viewModel.filterByEquipment(selection) }
            }
            .task { await viewModel.loadEquipment() }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(StyleKit.softInk)

            TextField("Search exercises", text: $searchText)
                .textFieldStyle(.plain)
                .foregroundStyle(StyleKit.ink)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 12)
        .appCard(padding: 0, radius: 14)
    }

    private func displayedExercises(recent: [ExerciseCatalogItem]) -> [ExerciseCatalogItem] {
        if viewModel.hasActiveFilter || !searchText.isEmpty {
            return viewModel.displayedExercises
        }
        return recent.isEmpty ? viewModel.popularExercises : recent
    }
}

private struct ExerciseIconView: View {
    let imageURL: URL?

    var body: some View {
        RemoteThumbnailView(
            imageURL: imageURL,
            size: 58,
            cornerRadius: 12,
            placeholder: placeholder
        )
    }

    private var placeholder: some View {
        Image(systemName: "figure.strengthtraining.traditional")
            .resizable()
            .scaledToFit()
            .padding(10)
            .foregroundStyle(StyleKit.softInk)
            .frame(width: 58, height: 58)
            .background(StyleKit.softChip)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Reusable Row Thumbnail

struct ExerciseRowThumbnail: View {
    let imageURL: URL?

    var body: some View {
        RemoteThumbnailView(
            imageURL: imageURL,
            size: 30,
            cornerRadius: 8,
            placeholder: placeholder
        )
    }

    private var placeholder: some View {
        Image(systemName: "figure.strengthtraining.traditional")
            .resizable()
            .scaledToFit()
            .padding(4)
            .foregroundStyle(StyleKit.softInk)
            .frame(width: 30, height: 30)
            .background(StyleKit.softChip)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    AddExerciseCatalogView { _ in }
        .environmentObject(RoutineStore())
}

// MARK: - View Model

@MainActor
final class ExerciseCatalogViewModel: ObservableObject {
    @Published var displayedExercises: [ExerciseCatalogItem] = []
    @Published var popularExercises: [ExerciseCatalogItem] = []
    @Published private var allExercises: [ExerciseCatalogItem] = []
    @Published var bodyParts: [String] = []
    @Published var equipment: [String] = []
    @Published var isLoading = false
    @Published var hasActiveFilter = false

    private let service = ExerciseDBService()
    private var currentTask: Task<Void, Never>?

    func loadPopular() async {
        guard popularExercises.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            if allExercises.isEmpty {
                let exercises = try await service.fetchAllExercises()
                allExercises = exercises.map(mapToCatalogItem)
            }
            popularExercises = Array(allExercises.prefix(20))
        } catch {
            popularExercises = []
        }
    }

    func search(text: String) async {
        currentTask?.cancel()
        guard !text.isEmpty else {
            displayedExercises = []
            hasActiveFilter = false
            return
        }

        currentTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            if Task.isCancelled { return }
            isLoading = true
            defer { isLoading = false }
            do {
                let query = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if !allExercises.isEmpty {
                    let localMatches = allExercises
                        .filter { $0.name.lowercased().contains(query) }
                        .prefix(50)
                    if !localMatches.isEmpty {
                        displayedExercises = Array(localMatches)
                        hasActiveFilter = true
                        return
                    }
                }

                let exercises = try await service.searchExercises(name: query)
                displayedExercises = exercises.map(mapToCatalogItem)
                hasActiveFilter = true
            } catch {
                displayedExercises = []
            }
        }
    }

    func loadBodyParts() async {
        if !bodyParts.isEmpty { return }
        do {
            bodyParts = try await service.bodyPartList()
        } catch {
            bodyParts = []
        }
    }

    func loadEquipment() async {
        if !equipment.isEmpty { return }
        do {
            equipment = try await service.equipmentList()
        } catch {
            equipment = []
        }
    }

    func filterByBodyPart(_ bodyPart: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let exercises = try await service.exercises(bodyPart: bodyPart)
            displayedExercises = exercises.map(mapToCatalogItem)
            hasActiveFilter = true
        } catch {
            displayedExercises = []
        }
    }

    func filterByEquipment(_ equipment: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let exercises = try await service.exercises(equipment: equipment)
            displayedExercises = exercises.map(mapToCatalogItem)
            hasActiveFilter = true
        } catch {
            displayedExercises = []
        }
    }

    func sectionTitle(recentIsEmpty: Bool) -> String {
        if hasActiveFilter { return "Results" }
        return recentIsEmpty ? "Popular" : "Recent"
    }

    private func mapToCatalogItem(_ exercise: ExerciseDBExercise) -> ExerciseCatalogItem {
        let imageURL = ExerciseDBConfig.baseURL
            .appendingPathComponent("image")
            .appending(queryItems: [
                URLQueryItem(name: "resolution", value: "180"),
                URLQueryItem(name: "exerciseId", value: exercise.id)
            ])

        return ExerciseCatalogItem(
            id: exercise.id,
            name: exercise.name.capitalized,
            muscle: exercise.target.capitalized,
            equipment: exercise.equipment.capitalized,
            imageURL: imageURL,
            mediaURL: exercise.gifUrl.flatMap(URL.init(string:)),
            primaryMuscle: exercise.target.capitalized,
            secondaryMuscles: [exercise.bodyPart.capitalized]
        )
    }
}

// MARK: - Category Picker

private struct CategoryPickerView: View {
    let title: String
    let items: [String]
    var onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundLayer()

                List {
                    ForEach(items, id: \.self) { item in
                        Button(item.capitalized) {
                            onSelect(item)
                            dismiss()
                        }
                        .foregroundStyle(StyleKit.ink)
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
            .navigationTitle(title)
        }
    }
}

// MARK: - Remote Thumbnail

struct RemoteThumbnailView<Placeholder: View>: View {
    let imageURL: URL?
    let size: CGFloat
    let cornerRadius: CGFloat
    let placeholder: Placeholder

    @State private var image: Image?

    var body: some View {
        Group {
            if let image {
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            } else {
                placeholder
            }
        }
        .task(id: imageURL) {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let url = imageURL else { return }
        do {
            var request = URLRequest(url: url)
            if url.host?.contains("rapidapi.com") == true {
                request.setValue(ExerciseDBConfig.apiKey, forHTTPHeaderField: "X-RapidAPI-Key")
                request.setValue(ExerciseDBConfig.host, forHTTPHeaderField: "X-RapidAPI-Host")
            }

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return
            }

            guard 200..<300 ~= httpResponse.statusCode else {
                return
            }

            guard let uiImage = UIImage(data: data) else {
                return
            }

            image = Image(uiImage: uiImage)
        } catch {
            // Keep placeholder on failure.
        }
    }
}
