import Foundation

/// Talks to the shared, no-client-key AI proxy (`pulse/apps-ai-proxy`) for the weekly digest
/// feature. No API key is embedded anywhere — the endpoint URL itself is the only secret-free
/// identifier shipped in the binary, same as every other app in this batch.
enum AIDigestClient {
    static let endpoint = URL(string: "https://apps-ai-proxy.s0533495227.workers.dev/text")!

    enum ClientError: LocalizedError {
        case badResponse
        case emptyContent
        case network(String)

        var errorDescription: String? {
            switch self {
            case .badResponse:
                return "The digest service didn't respond as expected. Try again in a moment."
            case .emptyContent:
                return "The digest came back empty. Try again in a moment."
            case .network(let message):
                return "Couldn't reach the digest service (\(message)). Check your connection and try again."
            }
        }
    }

    private struct ChatMessage: Encodable {
        let role: String
        let content: String
    }

    private struct RequestBody: Encodable {
        let messages: [ChatMessage]
    }

    private struct ResponseBody: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable { let content: String }
            let message: Message
        }
        let choices: [Choice]
    }

    /// Generates the one-line weekly digest. Never throws to the UI without a plain, human
    /// message — every failure path (network, HTTP, decode) is caught and turned into
    /// `ClientError` so a briefly-unavailable proxy never crashes the app.
    static func generateWeeklyDigest(systemPrompt: String, userPrompt: String) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(RequestBody(messages: [
            ChatMessage(role: "system", content: systemPrompt),
            ChatMessage(role: "user", content: userPrompt)
        ]))

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ClientError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw ClientError.badResponse
        }

        let decoded: ResponseBody
        do {
            decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        } catch {
            throw ClientError.badResponse
        }

        let content = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let content, !content.isEmpty else {
            throw ClientError.emptyContent
        }
        return content
    }
}
