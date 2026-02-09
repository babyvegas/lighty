import Foundation

struct ExerciseDBConfig {
    static let apiKey = resolveAPIKey()
    static let baseURL = URL(string: "https://exercisedb.p.rapidapi.com")!
    static let host = "exercisedb.p.rapidapi.com"

    private static func resolveAPIKey() -> String {
        // 1) Preferred: key injected into Info.plist from xcconfig.
        if let fromBundle = Bundle.main.object(forInfoDictionaryKey: "EXERCISEDB_API_KEY") as? String,
           !fromBundle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return fromBundle
        }

        // 2) Optional: scheme environment variable for local debugging.
        let fromEnv = ProcessInfo.processInfo.environment["EXERCISEDB_API_KEY"] ?? ""
        if !fromEnv.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return fromEnv
        }

#if DEBUG
        // 3) Debug fallback: read from local Config.xcconfig using source path.
        if let fromXCConfig = readAPIKeyFromLocalXCConfig(),
           !fromXCConfig.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return fromXCConfig
        }
#endif
        return ""
    }

#if DEBUG
    private static func readAPIKeyFromLocalXCConfig() -> String? {
        if let bundleURL = Bundle.main.url(forResource: "Config", withExtension: "xcconfig"),
           let fromBundle = readAPIKey(from: bundleURL) {
            return fromBundle
        }

        let sourceFilePath = URL(fileURLWithPath: #filePath)
        let projectRoot = sourceFilePath.deletingLastPathComponent().deletingLastPathComponent()
        let configURL = projectRoot.appendingPathComponent("Config.xcconfig")

        return readAPIKey(from: configURL)
    }

    private static func readAPIKey(from url: URL) -> String? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }

        for rawLine in content.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("EXERCISEDB_API_KEY") else { continue }
            let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            return parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return nil
    }
#endif
}

struct ExerciseDBExercise: Decodable {
    let id: String
    let name: String
    let bodyPart: String
    let target: String
    let equipment: String
    let gifUrl: String?
}

final class ExerciseDBService {
    func fetchAllExercises() async throws -> [ExerciseDBExercise] {
        let url = ExerciseDBConfig.baseURL.appendingPathComponent("exercises")
        return try await request(url: url)
    }

    func searchExercises(name: String) async throws -> [ExerciseDBExercise] {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let url = ExerciseDBConfig.baseURL
            .appendingPathComponent("exercises/name")
            .appendingPathComponent(normalized)
        return try await request(url: url)
    }

    func bodyPartList() async throws -> [String] {
        let url = ExerciseDBConfig.baseURL.appendingPathComponent("exercises/bodyPartList")
        return try await request(url: url)
    }

    func equipmentList() async throws -> [String] {
        let url = ExerciseDBConfig.baseURL.appendingPathComponent("exercises/equipmentList")
        return try await request(url: url)
    }

    func exercises(bodyPart: String) async throws -> [ExerciseDBExercise] {
        let url = ExerciseDBConfig.baseURL
            .appendingPathComponent("exercises/bodyPart")
            .appendingPathComponent(bodyPart)
        return try await request(url: url)
    }

    func exercises(equipment: String) async throws -> [ExerciseDBExercise] {
        let url = ExerciseDBConfig.baseURL
            .appendingPathComponent("exercises/equipment")
            .appendingPathComponent(equipment)
        return try await request(url: url)
    }

    private func request<T: Decodable>(url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue(ExerciseDBConfig.apiKey, forHTTPHeaderField: "X-RapidAPI-Key")
        request.setValue(ExerciseDBConfig.host, forHTTPHeaderField: "X-RapidAPI-Host")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

#if DEBUG
        if !(200..<300).contains(httpResponse.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? "<non-utf8 body>"
            print("[ExerciseDB] Status: \(httpResponse.statusCode)")
            print("[ExerciseDB] Response: \(body)")
        }
#endif
        guard 200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}
