import CloudKit
import Foundation

/// Fires once per logged visit so `ConstellationView` can animate the "handoff glow" traveling
/// from that sibling's node to center and back out to everyone — a transient event, not part of
/// the persisted model.
struct PulseEvent: Identifiable, Equatable {
    let id = UUID()
    let originSiblingID: String
    let firedAt = Date()
}

/// The full local snapshot, cached to disk so the app opens instantly and keeps working
/// offline. CloudKit is the source of truth for cross-device sync; this file is a fallback and
/// a fast first paint, exactly like `ParentSync`/`AppModel` elsewhere in this portfolio degrade
/// to local-only state when iCloud is briefly unreachable.
private struct LocalCache: Codable {
    var circle: CareCircle?
    var siblings: [Sibling]
    var visitLogs: [VisitLog]
    var handoffNotes: [HandoffNote]
    var mySiblingID: String?
    var participantOwnerName: String?
}

/// App state: owns the local cache, the CloudKit round-trip, the turn/handoff rules, and the
/// AI weekly digest. Pro itself is always read live from `Store` — never persisted here.
@MainActor
final class CareCircleStore: ObservableObject {
    @Published private(set) var circle: CareCircle?
    @Published private(set) var siblings: [Sibling] = []
    @Published private(set) var visitLogs: [VisitLog] = []
    @Published private(set) var handoffNotes: [HandoffNote] = []
    @Published var mySiblingID: String? {
        didSet { saveLocalCache() }
    }

    @Published private(set) var isSyncing = false
    @Published var syncErrorMessage: String?
    @Published var pulseEvent: PulseEvent?

    @Published private(set) var digestText: String?
    @Published var digestErrorMessage: String?
    @Published private(set) var isGeneratingDigest = false

    weak var store: Store?

    private let ck: CloudKitManager
    private var participantOwnerName: String?

    private static var cacheURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("handoff-cache.json")
    }

    init() {
        self.ck = CloudKitManager()
        loadLocalCache()
        Task { await bootstrap() }
    }

    // MARK: Local cache

    private func loadLocalCache() {
        guard let data = try? Data(contentsOf: Self.cacheURL),
              let cache = try? JSONDecoder().decode(LocalCache.self, from: data) else { return }
        circle = cache.circle
        siblings = cache.siblings.sorted { $0.orderIndex < $1.orderIndex }
        visitLogs = cache.visitLogs
        handoffNotes = cache.handoffNotes
        mySiblingID = cache.mySiblingID
        participantOwnerName = cache.participantOwnerName
    }

    private func saveLocalCache() {
        let cache = LocalCache(
            circle: circle,
            siblings: siblings,
            visitLogs: visitLogs,
            handoffNotes: handoffNotes,
            mySiblingID: mySiblingID,
            participantOwnerName: participantOwnerName
        )
        guard let data = try? JSONEncoder().encode(cache) else { return }
        try? data.write(to: Self.cacheURL, options: .atomic)
    }

    // MARK: Bootstrap / sync

    private func bootstrap() async {
        if let participantOwnerName {
            await ck.setParticipantOwnerName(participantOwnerName)
        }
        guard circle != nil else { return }
        await refreshFromCloud()
    }

    func refreshFromCloud() async {
        isSyncing = true
        defer { isSyncing = false }
        do {
            if participantOwnerName == nil { try await ck.ensureZoneExists() }
            await ck.ensureSubscription()
            let fetched = try await ck.fetchEverything()
            if let fetchedCircle = fetched.circle { circle = fetchedCircle }
            if !fetched.siblings.isEmpty { siblings = fetched.siblings }
            if !fetched.visits.isEmpty { visitLogs = fetched.visits }
            if !fetched.notes.isEmpty { handoffNotes = fetched.notes }
            syncErrorMessage = nil
            saveLocalCache()
        } catch {
            // Local-only fallback: the UI keeps working off the cache; the next refresh retries.
            syncErrorMessage = HandoffCKError.underlying(error.localizedDescription).errorDescription
        }
    }

    // MARK: Circle setup

    /// Creates a brand-new family circle on this device: the parent being cared for, plus this
    /// device's own sibling identity as the first (and, until invited, only) member.
    func createCircle(parentName: String, myName: String) async {
        let newCircle = CareCircle(parentName: parentName)
        let me = Sibling(name: myName, orderIndex: 0)
        circle = newCircle
        siblings = [me]
        mySiblingID = me.id
        saveLocalCache()

        do {
            try await ck.ensureZoneExists()
            await ck.ensureSubscription()
            try await ck.save(newCircle)
            try await ck.save(me)
            syncErrorMessage = nil
        } catch {
            syncErrorMessage = HandoffCKError.underlying(error.localizedDescription).errorDescription
        }
    }

    var canAddSibling: Bool {
        CareCircleLimits.canAddSibling(currentCount: siblings.count, isPro: store?.isPro ?? false)
    }

    @discardableResult
    func addSibling(name: String) async -> Bool {
        guard canAddSibling else { return false }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let sibling = Sibling(name: trimmed, orderIndex: siblings.count)
        siblings.append(sibling)
        saveLocalCache()
        do {
            try await ck.save(sibling)
            syncErrorMessage = nil
        } catch {
            syncErrorMessage = HandoffCKError.underlying(error.localizedDescription).errorDescription
        }
        return true
    }

    // MARK: Turn status

    /// The most recent handoff note addressed to a given sibling, if any — used both to decide
    /// whether their turn is officially active and to render the waiting banner.
    func mostRecentNote(to siblingID: String) -> HandoffNote? {
        handoffNotes.filter { $0.toSiblingID == siblingID }.max { $0.createdAt < $1.createdAt }
    }

    var turnStatus: TurnStatus {
        guard let circle else { return .active(siblingID: "") }
        let ids = siblings.map(\.id)
        let note = ids.indices.contains(circle.currentTurnIndex) ? mostRecentNote(to: ids[circle.currentTurnIndex]) : nil
        return HandoffTurnEngine.status(currentIndex: circle.currentTurnIndex, siblingIDs: ids, mostRecentNote: note)
    }

    var isMyTurnPendingRead: Bool {
        if case .waitingOnRead(_, let toID, _) = turnStatus, toID == mySiblingID { return true }
        return false
    }

    // MARK: Visits

    func logVisit(note: String, photoData: Data?) async {
        guard let mySiblingID else { return }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let log = VisitLog(siblingID: mySiblingID, note: trimmed, photoData: photoData)
        visitLogs.insert(log, at: 0)
        saveLocalCache()
        pulseEvent = PulseEvent(originSiblingID: mySiblingID)
        do {
            try await ck.save(log)
            syncErrorMessage = nil
        } catch {
            syncErrorMessage = HandoffCKError.underlying(error.localizedDescription).errorDescription
        }
    }

    // MARK: Handoff notes

    /// The outgoing sibling passes the baton: writes a note to whoever is next in rotation and
    /// advances the rotation index immediately. The turn is NOT active until that note is read.
    func sendHandoff(message: String) async {
        guard var circle = self.circle, let mySiblingID, !siblings.isEmpty else { return }
        let nextIndex = HandoffTurnEngine.nextIndex(current: circle.currentTurnIndex, count: siblings.count)
        guard siblings.indices.contains(nextIndex) else { return }
        let toID = siblings[nextIndex].id
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = HandoffNote(
            fromSiblingID: mySiblingID,
            toSiblingID: toID,
            message: trimmed.isEmpty ? "Your turn — nothing urgent to flag." : trimmed
        )
        handoffNotes.append(note)
        circle.currentTurnIndex = nextIndex
        self.circle = circle
        saveLocalCache()
        do {
            try await ck.save(note)
            try await ck.save(circle)
            syncErrorMessage = nil
        } catch {
            syncErrorMessage = HandoffCKError.underlying(error.localizedDescription).errorDescription
        }
    }

    /// The quirky feature's core action: the recipient actually opens and reads the note. Only
    /// this call — never delivery — sets `readAt`, and only this call makes the turn official.
    func markPendingNoteRead() async {
        guard let mySiblingID,
              let index = handoffNotes.firstIndex(where: { $0.toSiblingID == mySiblingID && $0.readAt == nil }) else { return }
        handoffNotes[index].readAt = .now
        let note = handoffNotes[index]
        saveLocalCache()
        do {
            try await ck.save(note)
            syncErrorMessage = nil
        } catch {
            syncErrorMessage = HandoffCKError.underlying(error.localizedDescription).errorDescription
        }
    }

    // MARK: Weekly digest (Pro)

    func generateWeeklyDigest() async {
        guard let circle else { return }
        isGeneratingDigest = true
        digestErrorMessage = nil
        defer { isGeneratingDigest = false }

        let names = Dictionary(uniqueKeysWithValues: siblings.map { ($0.id, $0.name) })
        let weekLogs = DigestPromptBuilder.thisWeek(visitLogs)
        let userPrompt = DigestPromptBuilder.buildUserPrompt(parentName: circle.parentName, logs: weekLogs, siblingNames: names)
        do {
            let result = try await AIDigestClient.generateWeeklyDigest(systemPrompt: DigestPromptBuilder.systemPrompt, userPrompt: userPrompt)
            digestText = result
        } catch {
            digestErrorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't generate the digest. Try again shortly."
        }
    }

    // MARK: Sharing

    func createOrFetchShare() async throws -> CKShare {
        let title = "Handoff — \(circle?.parentName ?? "Care Circle")"
        return try await ck.makeOrFetchZoneShare(title: title)
    }

    func acceptShare(metadata: CKShare.Metadata) async {
        do {
            let ownerName = try await ck.acceptShare(metadata: metadata)
            participantOwnerName = ownerName
            await ck.setParticipantOwnerName(ownerName)
            saveLocalCache()
            await refreshFromCloud()
        } catch {
            syncErrorMessage = HandoffCKError.underlying(error.localizedDescription).errorDescription
        }
    }

    // MARK: Data

    func deleteAllLocalData() {
        circle = nil
        siblings = []
        visitLogs = []
        handoffNotes = []
        mySiblingID = nil
        participantOwnerName = nil
        try? FileManager.default.removeItem(at: Self.cacheURL)
    }
}
