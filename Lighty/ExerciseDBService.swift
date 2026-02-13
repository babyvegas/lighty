import Foundation

struct ExerciseDBConfig {
    static let baseURL = URL(string: "https://wger.de/api/v2")!
    static let mediaHost = URL(string: "https://wger.de")!
    static let apiKey = resolveAPIKey()

    private static func resolveAPIKey() -> String {
        // Optional token support for private/self-hosted wger installations.
        if let fromBundle = Bundle.main.object(forInfoDictionaryKey: "WGER_API_KEY") as? String,
           !fromBundle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return fromBundle
        }

        let fromEnv = ProcessInfo.processInfo.environment["WGER_API_KEY"] ?? ""
        if !fromEnv.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return fromEnv
        }
        return ""
    }
}

struct ExerciseDBExercise {
    let id: String
    let name: String
    let bodyPart: String
    let target: String
    let equipment: String
    let gifUrl: String?
    let imageUrl: String?
    let secondaryMuscles: [String]
    let equipmentItems: [String]
}

private extension URL {
    func appending(queryItems: [URLQueryItem]) -> URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return self
        }
        components.queryItems = (components.queryItems ?? []) + queryItems
        return components.url ?? self
    }
}

private struct WgerPage<T: Decodable>: Decodable {
    let count: Int
    let next: String?
    let previous: String?
    let results: [T]
}

private struct WgerNamedReference: Decodable {
    let id: Int
    let name: String?
    let nameEn: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case nameEn = "name_en"
    }
}

private struct WgerReferenceOrID: Decodable {
    let id: Int
    let name: String?
    let nameEn: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Int.self) {
            id = value
            name = nil
            nameEn = nil
            return
        }

        let reference = try container.decode(WgerNamedReference.self)
        id = reference.id
        name = reference.name
        nameEn = reference.nameEn
    }
}

private struct WgerTranslation: Decodable {
    let name: String?
    let languageID: Int?

    enum CodingKeys: String, CodingKey {
        case name
        case language
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name)

        if let directID = try? container.decode(Int.self, forKey: .language) {
            languageID = directID
            return
        }

        if let language = try? container.decode(WgerReferenceOrID.self, forKey: .language) {
            languageID = language.id
            return
        }

        languageID = nil
    }
}

private struct WgerExerciseImage: Decodable {
    let image: String?
    let isMain: Bool?

    enum CodingKeys: String, CodingKey {
        case image
        case isMain = "is_main"
    }
}

private struct WgerExerciseVideo: Decodable {
    let video: String?
}

private struct WgerExerciseInfo: Decodable {
    let id: Int
    let category: WgerReferenceOrID?
    let muscles: [WgerReferenceOrID]
    let musclesSecondary: [WgerReferenceOrID]
    let equipment: [WgerReferenceOrID]
    let translations: [WgerTranslation]
    let images: [WgerExerciseImage]
    let videos: [WgerExerciseVideo]

    enum CodingKeys: String, CodingKey {
        case id
        case category
        case muscles
        case musclesSecondary = "muscles_secondary"
        case equipment
        case translations
        case images
        case videos
    }
}

private struct WgerSearchResponse: Decodable {
    let suggestions: [WgerSearchSuggestion]
}

private struct WgerSearchSuggestion: Decodable {
    let value: String
    let data: WgerSearchSuggestionData
}

private struct WgerSearchSuggestionData: Decodable {
    let id: Int?
    let baseID: Int?
    let name: String?
    let category: String?
    let image: String?
    let imageThumbnail: String?

    enum CodingKeys: String, CodingKey {
        case id
        case baseID = "base_id"
        case name
        case category
        case image
        case imageThumbnail = "image_thumbnail"
    }
}

@MainActor
final class ExerciseDBService {
    private let preferredLanguageIDs = [2, 4] // English, Spanish

    private var cachedExercises: [ExerciseDBExercise]?
    private var cachedMuscleNames: [String]?
    private var cachedEquipmentNames: [String]?
    private var muscleIDByName: [String: Int] = [:]
    private var equipmentIDByName: [String: Int] = [:]

    func fetchPopularExercises(limit: Int = 24) async throws -> [ExerciseDBExercise] {
        let cappedLimit = max(1, min(limit, 100))
        return try await loadExercisesFromWger(
            queryItems: [URLQueryItem(name: "language", value: "2")],
            maxResults: cappedLimit,
            pageSize: cappedLimit
        )
    }

    func fetchAllExercises() async throws -> [ExerciseDBExercise] {
        if let cachedExercises {
            return cachedExercises
        }

        let exercises = try await loadExercisesFromWger(
            queryItems: [URLQueryItem(name: "language", value: "2")]
        )
        cachedExercises = exercises
        return exercises
    }

    func searchExercises(name: String) async throws -> [ExerciseDBExercise] {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return [] }

        do {
            let response = try await searchResponse(term: normalized)
            let cachedByID = Dictionary(uniqueKeysWithValues: (cachedExercises ?? []).map { ($0.id, $0) })

            let mapped = response.suggestions.prefix(40).compactMap { suggestion -> ExerciseDBExercise? in
                let rawID = suggestion.data.baseID ?? suggestion.data.id
                guard let rawID else { return nil }
                let exerciseID = String(rawID)

                if let cached = cachedByID[exerciseID] {
                    let thumbnail = absoluteMediaURL(suggestion.data.imageThumbnail)
                    return ExerciseDBExercise(
                        id: cached.id,
                        name: cached.name,
                        bodyPart: cached.bodyPart,
                        target: cached.target,
                        equipment: cached.equipment,
                        gifUrl: cached.gifUrl,
                        imageUrl: thumbnail ?? cached.imageUrl,
                        secondaryMuscles: cached.secondaryMuscles,
                        equipmentItems: cached.equipmentItems
                    )
                }

                let category = normalizeLabel(suggestion.data.category ?? "Unknown")
                let displayName = normalizeLabel(
                    suggestion.data.name ?? suggestion.value
                )

                return ExerciseDBExercise(
                    id: exerciseID,
                    name: displayName,
                    bodyPart: category,
                    target: category,
                    equipment: "Bodyweight",
                    gifUrl: nil,
                    imageUrl: absoluteMediaURL(suggestion.data.imageThumbnail ?? suggestion.data.image),
                    secondaryMuscles: [],
                    equipmentItems: []
                )
            }

            if !mapped.isEmpty {
                return mapped
            }
        } catch {
            // Fall through to local fallback.
        }

        // Avoid downloading full catalog as a fallback on every failed query.
        // If we already have local cache, use it; otherwise return no results quickly.
        guard let cachedExercises else { return [] }
        let query = normalized.lowercased()
        return cachedExercises
            .filter { $0.name.lowercased().contains(query) }
            .prefix(60)
            .map { $0 }
    }

    func bodyPartList() async throws -> [String] {
        if let cachedMuscleNames {
            return cachedMuscleNames
        }

        let map = try await fetchReferenceMap(path: "muscle/")
        var byName: [String: Int] = [:]
        let names = map.compactMap { (id, rawName) -> String? in
            let normalized = normalizeLabel(rawName)
            guard !normalized.isEmpty else { return nil }
            byName[normalized.lowercased()] = id
            return normalized
        }
        .sorted()

        muscleIDByName = byName
        cachedMuscleNames = names
        return names
    }

    func equipmentList() async throws -> [String] {
        if let cachedEquipmentNames {
            return cachedEquipmentNames
        }

        let map = try await fetchReferenceMap(path: "equipment/")
        var byName: [String: Int] = [:]
        let names = map.compactMap { (id, rawName) -> String? in
            let normalized = normalizeLabel(rawName)
            guard !normalized.isEmpty else { return nil }
            byName[normalized.lowercased()] = id
            return normalized
        }
        .sorted()

        equipmentIDByName = byName
        cachedEquipmentNames = names
        return names
    }

    func exercises(bodyPart: String) async throws -> [ExerciseDBExercise] {
        let normalized = bodyPart.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return [] }

        if muscleIDByName.isEmpty {
            _ = try await bodyPartList()
        }

        if let muscleID = muscleIDByName[normalized] {
            return try await loadExercisesFromWger(
                queryItems: [
                    URLQueryItem(name: "language", value: "2"),
                    URLQueryItem(name: "muscles", value: String(muscleID))
                ],
                maxResults: 300,
                pageSize: 100
            )
        }

        let exercises = try await fetchAllExercises()
        return exercises.filter { exercise in
            if exercise.target.lowercased().contains(normalized) { return true }
            if exercise.bodyPart.lowercased().contains(normalized) { return true }
            return exercise.secondaryMuscles.contains { $0.lowercased().contains(normalized) }
        }
    }

    func exercises(equipment: String) async throws -> [ExerciseDBExercise] {
        let normalized = equipment.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return [] }

        if equipmentIDByName.isEmpty {
            _ = try await equipmentList()
        }

        if let equipmentID = equipmentIDByName[normalized] {
            return try await loadExercisesFromWger(
                queryItems: [
                    URLQueryItem(name: "language", value: "2"),
                    URLQueryItem(name: "equipment", value: String(equipmentID))
                ],
                maxResults: 300,
                pageSize: 100
            )
        }

        let exercises = try await fetchAllExercises()
        return exercises.filter { exercise in
            if exercise.equipment.lowercased().contains(normalized) { return true }
            return exercise.equipmentItems.contains { $0.lowercased().contains(normalized) }
        }
    }

    private func request<T: Decodable>(url: URL) async throws -> T {
        var request = URLRequest(url: url)
        if !ExerciseDBConfig.apiKey.isEmpty {
            request.setValue("Token \(ExerciseDBConfig.apiKey)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    private func searchResponse(term: String) async throws -> WgerSearchResponse {
        var allSuggestions: [WgerSearchSuggestion] = []
        var seenIDs = Set<Int>()

        for languageID in preferredLanguageIDs {
            let endpoint = ExerciseDBConfig.baseURL
                .appendingPathComponent("exercise/search/")
                .appending(queryItems: [
                    URLQueryItem(name: "term", value: term),
                    URLQueryItem(name: "language", value: String(languageID))
                ])

            let response: WgerSearchResponse = try await request(url: endpoint)
            for suggestion in response.suggestions {
                guard let rawID = suggestion.data.baseID ?? suggestion.data.id else { continue }
                guard !seenIDs.contains(rawID) else { continue }
                seenIDs.insert(rawID)
                allSuggestions.append(suggestion)
            }
        }

        return WgerSearchResponse(suggestions: allSuggestions)
    }

    private func loadExercisesFromWger(
        queryItems: [URLQueryItem] = [],
        maxResults: Int? = nil,
        pageSize: Int = 200
    ) async throws -> [ExerciseDBExercise] {
        let infos = try await fetchExerciseInfoPages(
            queryItems: queryItems,
            maxResults: maxResults,
            pageSize: pageSize
        )

        var seen = Set<String>()
        var mapped: [ExerciseDBExercise] = []
        mapped.reserveCapacity(infos.count)

        for info in infos {
            guard let exercise = mapExercise(info) else { continue }
            guard !seen.contains(exercise.id) else { continue }
            seen.insert(exercise.id)
            mapped.append(exercise)
        }

        return mapped
    }

    private func fetchExerciseInfoPages(
        queryItems: [URLQueryItem],
        maxResults: Int?,
        pageSize: Int
    ) async throws -> [WgerExerciseInfo] {
        var allResults: [WgerExerciseInfo] = []
        var offset = 0
        let cappedPageSize = max(1, min(pageSize, 200))

        while true {
            var items = queryItems
            items.append(URLQueryItem(name: "limit", value: String(cappedPageSize)))
            items.append(URLQueryItem(name: "offset", value: String(offset)))

            let url = ExerciseDBConfig.baseURL
                .appendingPathComponent("exerciseinfo/")
                .appending(queryItems: items)

            let page: WgerPage<WgerExerciseInfo> = try await request(url: url)
            allResults.append(contentsOf: page.results)

            if let maxResults, allResults.count >= maxResults {
                return Array(allResults.prefix(maxResults))
            }

            if page.next == nil { break }
            offset += cappedPageSize
            if offset >= page.count { break }
        }

        return allResults
    }

    private func fetchReferenceMap(path: String) async throws -> [Int: String] {
        var map: [Int: String] = [:]
        var offset = 0
        let limit = 200

        while true {
            let url = ExerciseDBConfig.baseURL
                .appendingPathComponent(path)
                .appending(queryItems: [
                    URLQueryItem(name: "limit", value: String(limit)),
                    URLQueryItem(name: "offset", value: String(offset))
                ])

            let page: WgerPage<WgerNamedReference> = try await request(url: url)
            for item in page.results {
                let raw = item.nameEn ?? item.name ?? ""
                let normalized = normalizeLabel(raw)
                if !normalized.isEmpty {
                    map[item.id] = normalized
                }
            }

            if page.next == nil { break }
            offset += limit
            if offset >= page.count { break }
        }

        return map
    }

    private func mapExercise(_ info: WgerExerciseInfo) -> ExerciseDBExercise? {
        let name = preferredName(from: info.translations)
        guard !name.isEmpty else { return nil }

        let primaryMuscles = info.muscles
            .map { normalizeLabel($0.nameEn ?? $0.name ?? "") }
            .filter { !$0.isEmpty }

        let secondaryMuscles = info.musclesSecondary
            .map { normalizeLabel($0.nameEn ?? $0.name ?? "") }
            .filter { !$0.isEmpty }

        let category = normalizeLabel(info.category?.nameEn ?? info.category?.name ?? "")
        let target = primaryMuscles.first ?? secondaryMuscles.first ?? category
        let bodyPart = secondaryMuscles.first ?? category

        let equipmentItems = info.equipment
            .map { normalizeLabel($0.nameEn ?? $0.name ?? "") }
            .filter { !$0.isEmpty }

        let equipment = equipmentItems.first ?? "Bodyweight"
        let imageURL = preferredImageURL(from: info.images)
        let videoURL = info.videos.compactMap(\.video).first

        return ExerciseDBExercise(
            id: String(info.id),
            name: name,
            bodyPart: bodyPart,
            target: target,
            equipment: equipment,
            gifUrl: videoURL,
            imageUrl: imageURL,
            secondaryMuscles: secondaryMuscles,
            equipmentItems: equipmentItems
        )
    }

    private func preferredName(from translations: [WgerTranslation]) -> String {
        for languageID in preferredLanguageIDs {
            if let match = translations.first(where: {
                $0.languageID == languageID &&
                ($0.name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            }) {
                return normalizeLabel(match.name ?? "")
            }
        }

        if let fallback = translations.first(where: {
            guard let value = $0.name?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                return false
            }
            return !value.isEmpty
        }) {
            return normalizeLabel(fallback.name ?? "")
        }

        return ""
    }

    private func preferredImageURL(from images: [WgerExerciseImage]) -> String? {
        let mainImage = images.first(where: { $0.isMain == true })?.image
        let fallbackImage = images.first?.image
        return absoluteMediaURL(mainImage ?? fallbackImage)
    }

    private func absoluteMediaURL(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        if raw.hasPrefix("http://") || raw.hasPrefix("https://") {
            return raw
        }

        if raw.hasPrefix("/") {
            return ExerciseDBConfig.mediaHost
                .appendingPathComponent(String(raw.dropFirst()))
                .absoluteString
        }

        return ExerciseDBConfig.mediaHost.appendingPathComponent(raw).absoluteString
    }

    private func normalizeLabel(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }
}
