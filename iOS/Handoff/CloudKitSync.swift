import CloudKit
import Foundation

/// CloudKit plumbing for the family "care circle": one custom, zone-wide-shared
/// `CKRecordZone` per family. The person who sets the circle up owns the zone in their
/// *private* database and shares the whole zone via a single `CKShare`; every sibling who
/// accepts the invite reads/writes the same records through their own *shared* database.
/// This is real multi-user sync via CloudKit sharing, not a custom backend.
enum HandoffCK {
    static let containerIdentifier = "iCloud.com.shimondeitel.handoff"
    static let zoneName = "CareCircleZone"

    enum RecordType {
        static let careCircle = "CareCircle"
        static let sibling = "Sibling"
        static let visitLog = "VisitLog"
        static let handoffNote = "HandoffNote"
    }
}

enum HandoffCKError: LocalizedError {
    case notSignedIn
    case shareUnavailable
    case underlying(String)

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "Sign in to iCloud in Settings to sync your care circle with your siblings."
        case .shareUnavailable:
            return "Could not create a share link right now. Check your connection and try again."
        case .underlying(let message):
            return message
        }
    }
}

/// Reads/writes a small photo as a `CKAsset` via a temp file, since `CKAsset` has no
/// in-memory-data initializer.
enum PhotoAssetCoder {
    static func write(data: Data?, name: String) -> CKAsset? {
        guard let data else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(name)-\(UUID().uuidString).jpg")
        do {
            try data.write(to: url)
            return CKAsset(fileURL: url)
        } catch {
            return nil
        }
    }

    static func read(_ asset: CKAsset?) -> Data? {
        guard let url = asset?.fileURL else { return nil }
        return try? Data(contentsOf: url)
    }
}

// MARK: - Record <-> model conversions

extension CareCircle {
    func toRecord(zoneID: CKRecordZone.ID) -> CKRecord {
        let record = CKRecord(recordType: HandoffCK.RecordType.careCircle, recordID: CKRecord.ID(recordName: id, zoneID: zoneID))
        record["parentName"] = parentName as CKRecordValue
        record["currentTurnIndex"] = currentTurnIndex as CKRecordValue
        record["createdAt"] = createdAt as CKRecordValue
        if let asset = PhotoAssetCoder.write(data: parentPhotoData, name: "parent") {
            record["parentPhoto"] = asset
        }
        return record
    }

    init?(record: CKRecord) {
        guard record.recordType == HandoffCK.RecordType.careCircle,
              let parentName = record["parentName"] as? String,
              let currentTurnIndex = record["currentTurnIndex"] as? Int,
              let createdAt = record["createdAt"] as? Date else { return nil }
        self.init(
            id: record.recordID.recordName,
            parentName: parentName,
            parentPhotoData: PhotoAssetCoder.read(record["parentPhoto"] as? CKAsset),
            currentTurnIndex: currentTurnIndex,
            createdAt: createdAt
        )
    }
}

extension Sibling {
    func toRecord(zoneID: CKRecordZone.ID) -> CKRecord {
        let record = CKRecord(recordType: HandoffCK.RecordType.sibling, recordID: CKRecord.ID(recordName: id, zoneID: zoneID))
        record["name"] = name as CKRecordValue
        record["orderIndex"] = orderIndex as CKRecordValue
        record["joinedAt"] = joinedAt as CKRecordValue
        if let asset = PhotoAssetCoder.write(data: photoData, name: "sibling") {
            record["photo"] = asset
        }
        return record
    }

    init?(record: CKRecord) {
        guard record.recordType == HandoffCK.RecordType.sibling,
              let name = record["name"] as? String,
              let orderIndex = record["orderIndex"] as? Int,
              let joinedAt = record["joinedAt"] as? Date else { return nil }
        self.init(
            id: record.recordID.recordName,
            name: name,
            orderIndex: orderIndex,
            photoData: PhotoAssetCoder.read(record["photo"] as? CKAsset),
            joinedAt: joinedAt
        )
    }
}

extension VisitLog {
    func toRecord(zoneID: CKRecordZone.ID) -> CKRecord {
        let record = CKRecord(recordType: HandoffCK.RecordType.visitLog, recordID: CKRecord.ID(recordName: id, zoneID: zoneID))
        record["siblingID"] = siblingID as CKRecordValue
        record["note"] = note as CKRecordValue
        record["createdAt"] = createdAt as CKRecordValue
        if let asset = PhotoAssetCoder.write(data: photoData, name: "visit") {
            record["photo"] = asset
        }
        return record
    }

    init?(record: CKRecord) {
        guard record.recordType == HandoffCK.RecordType.visitLog,
              let siblingID = record["siblingID"] as? String,
              let note = record["note"] as? String,
              let createdAt = record["createdAt"] as? Date else { return nil }
        self.init(
            id: record.recordID.recordName,
            siblingID: siblingID,
            note: note,
            photoData: PhotoAssetCoder.read(record["photo"] as? CKAsset),
            createdAt: createdAt
        )
    }
}

extension HandoffNote {
    func toRecord(zoneID: CKRecordZone.ID) -> CKRecord {
        let record = CKRecord(recordType: HandoffCK.RecordType.handoffNote, recordID: CKRecord.ID(recordName: id, zoneID: zoneID))
        record["fromSiblingID"] = fromSiblingID as CKRecordValue
        record["toSiblingID"] = toSiblingID as CKRecordValue
        record["message"] = message as CKRecordValue
        record["createdAt"] = createdAt as CKRecordValue
        if let readAt {
            record["readAt"] = readAt as CKRecordValue
        }
        return record
    }

    init?(record: CKRecord) {
        guard record.recordType == HandoffCK.RecordType.handoffNote,
              let fromSiblingID = record["fromSiblingID"] as? String,
              let toSiblingID = record["toSiblingID"] as? String,
              let message = record["message"] as? String,
              let createdAt = record["createdAt"] as? Date else { return nil }
        self.init(
            id: record.recordID.recordName,
            fromSiblingID: fromSiblingID,
            toSiblingID: toSiblingID,
            message: message,
            createdAt: createdAt,
            readAt: record["readAt"] as? Date
        )
    }
}

/// One family circle's CloudKit round-trip: which zone/database to use, plus save/fetch/share
/// operations. Owns no app state itself — `CareCircleStore` holds the cached model and calls
/// into this for network work, degrading to local-only on any failure.
actor CloudKitManager {
    let container: CKContainer
    /// nil = this device owns the zone (uses the private database). Non-nil = this device
    /// accepted a share and reads/writes through the shared database, scoped to the owner's
    /// zone by their CloudKit user record name.
    private(set) var participantOwnerName: String?

    init(participantOwnerName: String? = nil) {
        self.container = CKContainer(identifier: HandoffCK.containerIdentifier)
        self.participantOwnerName = participantOwnerName
    }

    func setParticipantOwnerName(_ ownerName: String?) {
        self.participantOwnerName = ownerName
    }

    private var database: CKDatabase {
        participantOwnerName == nil ? container.privateCloudDatabase : container.sharedCloudDatabase
    }

    private var zoneID: CKRecordZone.ID {
        CKRecordZone.ID(zoneName: HandoffCK.zoneName, ownerName: participantOwnerName ?? CKCurrentUserDefaultName)
    }

    func accountStatus() async throws -> CKAccountStatus {
        try await container.accountStatus()
    }

    /// Creates the custom zone if this device owns it. No-op (and unnecessary) for participants,
    /// whose zone already exists on the owner's private database the moment they accept a share.
    func ensureZoneExists() async throws {
        guard participantOwnerName == nil else { return }
        let zone = CKRecordZone(zoneID: zoneID)
        _ = try await database.save(zone)
    }

    /// Registers a silent-push subscription (owner: one zone in the private DB; participant:
    /// the whole shared DB, since that's all a share grants) so every sibling's device learns
    /// about a change soon after it happens, not only on next foreground refresh. Backs the
    /// `remote-notification` background mode + `aps-environment` entitlement. Safe to call on
    /// every launch — a duplicate subscription ID simply fails the save, which is ignored.
    func ensureSubscription() async {
        let subscriptionID = "handoff-zone-changes"
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true

        let subscription: CKSubscription
        if participantOwnerName == nil {
            subscription = CKRecordZoneSubscription(zoneID: zoneID, subscriptionID: subscriptionID)
        } else {
            subscription = CKDatabaseSubscription(subscriptionID: subscriptionID)
        }
        subscription.notificationInfo = notificationInfo
        _ = try? await database.save(subscription)
    }

    // MARK: Save

    @discardableResult
    func save(_ circle: CareCircle) async throws -> CKRecord {
        try await database.save(circle.toRecord(zoneID: zoneID))
    }

    @discardableResult
    func save(_ sibling: Sibling) async throws -> CKRecord {
        try await database.save(sibling.toRecord(zoneID: zoneID))
    }

    @discardableResult
    func save(_ visitLog: VisitLog) async throws -> CKRecord {
        try await database.save(visitLog.toRecord(zoneID: zoneID))
    }

    @discardableResult
    func save(_ note: HandoffNote) async throws -> CKRecord {
        try await database.save(note.toRecord(zoneID: zoneID))
    }

    // MARK: Fetch

    private func fetchAll(recordType: String) async throws -> [CKRecord] {
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        var results: [CKRecord] = []
        var cursor: CKQueryOperation.Cursor?
        repeat {
            let page: (matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?)
            if let cursor {
                page = try await database.records(continuingMatchFrom: cursor)
            } else {
                page = try await database.records(matching: query, inZoneWith: zoneID)
            }
            for (_, result) in page.matchResults {
                if case .success(let record) = result { results.append(record) }
            }
            cursor = page.queryCursor
        } while cursor != nil
        return results
    }

    func fetchEverything() async throws -> (circle: CareCircle?, siblings: [Sibling], visits: [VisitLog], notes: [HandoffNote]) {
        let circleRecords = try await fetchAll(recordType: HandoffCK.RecordType.careCircle)
        let siblingRecords = try await fetchAll(recordType: HandoffCK.RecordType.sibling)
        let visitRecords = try await fetchAll(recordType: HandoffCK.RecordType.visitLog)
        let noteRecords = try await fetchAll(recordType: HandoffCK.RecordType.handoffNote)
        return (
            circleRecords.compactMap(CareCircle.init(record:)).first,
            siblingRecords.compactMap(Sibling.init(record:)).sorted { $0.orderIndex < $1.orderIndex },
            visitRecords.compactMap(VisitLog.init(record:)),
            noteRecords.compactMap(HandoffNote.init(record:))
        )
    }

    // MARK: Sharing (owner side)

    /// Fetches the zone's existing zone-wide share, if one has already been created.
    func existingZoneShare() async -> CKShare? {
        guard participantOwnerName == nil else { return nil }
        let shareID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zoneID)
        guard let record = try? await database.record(for: shareID) else { return nil }
        return record as? CKShare
    }

    /// Creates (or returns the existing) zone-wide share for this family's zone. Every sibling
    /// who accepts the resulting invite link reads/writes the exact same zone.
    func makeOrFetchZoneShare(title: String) async throws -> CKShare {
        if let existing = await existingZoneShare() { return existing }
        try await ensureZoneExists()
        let share = CKShare(recordZoneID: zoneID)
        share[CKShare.SystemFieldKey.title] = title as CKRecordValue
        share.publicPermission = .none
        guard let saved = try await database.save(share) as? CKShare else {
            throw HandoffCKError.shareUnavailable
        }
        return saved
    }

    // MARK: Sharing (participant side)

    /// Accepts an invite the user tapped, via the operation-based API (the share metadata
    /// arrives through `application(_:userDidAcceptCloudKitShareWith:)`). Returns the owner's
    /// CloudKit user record name so the caller can persist it and switch to the shared database.
    func acceptShare(metadata: CKShare.Metadata) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let operation = CKAcceptSharesOperation(shareMetadatas: [metadata])
            operation.acceptSharesResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: metadata.share.recordID.zoneID.ownerName)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            container.add(operation)
        }
    }
}
