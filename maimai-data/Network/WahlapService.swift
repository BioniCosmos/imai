import Foundation

enum WahlapService {
    private static var serverURL: URL {
        URL(string: Constants.wahlapServerURL)!
    }

    // MARK: - API Types

    struct CreateTaskResponse: Decodable {
        let taskId: String

        enum CodingKeys: String, CodingKey {
            case taskId = "task_id"
        }
    }

    struct DifficultyResult: Decodable {
        let difficulty: Int
        let name: String
        let status: String
        let error: String?
    }

    struct TaskStatus: Decodable {
        let taskId: String
        let state: String
        let results: [DifficultyResult]?
        let errorMessage: String?

        enum CodingKeys: String, CodingKey {
            case taskId = "task_id"
            case state
            case results
            case errorMessage = "error_message"
        }

        var isTerminal: Bool {
            state == "completed" || state == "failed"
        }
    }

    // MARK: - API Calls

    /// Step 1: Create a task on the server.
    static func createTask(
        username: String,
        password: String,
        difficulties: [Int] = [0, 1, 2, 3, 4]
    ) async throws -> CreateTaskResponse {
        let url = serverURL.appending(path: "/api/tasks")
        let body: [String: Any] = [
            "diving_fish_username": username,
            "diving_fish_password": password,
            "difficulties": difficulties
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        let data = try await MaimaiDataClient.shared.request(
            url: url,
            method: "POST",
            headers: ["Content-Type": "application/json"],
            body: bodyData
        )
        return try MaimaiDataClient.shared.decode(CreateTaskResponse.self, from: data)
    }

    /// Step 7: Poll task status until terminal.
    static func getTask(id: String) async throws -> TaskStatus {
        let url = serverURL.appending(path: "/api/tasks/\(id)")
        let data = try await MaimaiDataClient.shared.request(url: url)
        return try MaimaiDataClient.shared.decode(TaskStatus.self, from: data)
    }

    /// Poll until the task reaches a terminal state.
    static func waitForTask(id: String, pollInterval: TimeInterval = 2.0) async throws -> TaskStatus {
        while true {
            let status = try await getTask(id: id)
            if status.isTerminal {
                return status
            }
            try await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
        }
    }
}
