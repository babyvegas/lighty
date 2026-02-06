import Foundation

struct ExerciseDBConfig {
    // Replace with your RapidAPI key from ExerciseDB.
    static let apiKey = "89f1cefde4msh55fa5713ea26680p1eb6c1jsn2a185e47cd03"
    static let baseURL = URL(string: "https://exercisedb.p.rapidapi.com")!
    static let host = "exercisedb.p.rapidapi.com"
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
        let url = ExerciseDBConfig.baseURL
            .appendingPathComponent("exercises/name")
            .appendingPathComponent(name)
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
        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}
