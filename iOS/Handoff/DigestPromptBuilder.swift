import Foundation

/// Builds the deterministic prompt text sent to the shared AI proxy for the weekly digest.
/// Pure string assembly only — the actual network call lives in `AIDigestClient`.
enum DigestPromptBuilder {
    static let systemPrompt = """
    You write a single warm, specific one-sentence weekly digest for a family care circle. \
    You are told the parent's name and a set of short visit notes logged by different \
    siblings over the past week. Combine them into ONE sentence (max ~30 words) for the \
    sibling who lives far away and could not visit in person. Be specific (name who did what) \
    and warm, never clinical. If a note mentions something still unresolved, gently include it. \
    Reply with ONLY the single sentence — no preamble, no quotation marks.
    """

    /// Visit logs from the last 7 days, most recent first — the digest should only ever
    /// summarize the current week, not the whole history.
    static func thisWeek(_ logs: [VisitLog], now: Date = .now, calendar: Calendar = .current) -> [VisitLog] {
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) else { return [] }
        return logs
            .filter { $0.createdAt >= weekAgo && $0.createdAt <= now }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// The user-turn prompt: parent's name plus every sibling's note this week, each labeled
    /// with the sibling's name so the model can attribute specific actions correctly.
    static func buildUserPrompt(parentName: String, logs: [VisitLog], siblingNames: [String: String]) -> String {
        guard !logs.isEmpty else {
            return "Parent: \(parentName). No visit notes were logged this week."
        }
        var lines = ["Parent: \(parentName).", "This week's notes, oldest first:"]
        for log in logs.sorted(by: { $0.createdAt < $1.createdAt }) {
            let name = siblingNames[log.siblingID] ?? "A sibling"
            lines.append("- \(name): \(log.note)")
        }
        return lines.joined(separator: "\n")
    }
}
