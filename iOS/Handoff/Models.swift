import Foundation

/// One sibling in the care circle. `id` is a stable, app-owned UUID string (also used as the
/// CloudKit record name) so logic never depends on CloudKit being reachable.
struct Sibling: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    /// Position in the rotation order — also indexes into `HandoffColor.sibling(_:)`.
    var orderIndex: Int
    /// Small JPEG thumbnail, optional. Falls back to initials-in-a-circle when nil.
    var photoData: Data?
    var joinedAt: Date

    init(id: String = UUID().uuidString, name: String, orderIndex: Int, photoData: Data? = nil, joinedAt: Date = .now) {
        self.id = id
        self.name = name
        self.orderIndex = orderIndex
        self.photoData = photoData
        self.joinedAt = joinedAt
    }

    var initials: String {
        let parts = name.split(separator: " ")
        let chars = parts.prefix(2).compactMap { $0.first }
        return chars.isEmpty ? "?" : String(chars).uppercased()
    }
}

/// The shared "care circle" itself: the parent being cared for, plus whose turn it is right
/// now. One circle per family, shared to every sibling via a single CloudKit `CKShare`.
struct CareCircle: Codable, Equatable {
    var id: String
    var parentName: String
    var parentPhotoData: Data?
    /// Index into the (order-sorted) sibling list — whoever is nominally on duty right now.
    var currentTurnIndex: Int
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        parentName: String,
        parentPhotoData: Data? = nil,
        currentTurnIndex: Int = 0,
        createdAt: Date = .now
    ) {
        self.id = id
        self.parentName = parentName
        self.parentPhotoData = parentPhotoData
        self.currentTurnIndex = currentTurnIndex
        self.createdAt = createdAt
    }
}

/// A short post-visit or post-call note logged by whichever sibling was just there.
struct VisitLog: Identifiable, Codable, Equatable {
    var id: String
    var siblingID: String
    var note: String
    var photoData: Data?
    var createdAt: Date

    init(id: String = UUID().uuidString, siblingID: String, note: String, photoData: Data? = nil, createdAt: Date = .now) {
        self.id = id
        self.siblingID = siblingID
        self.note = note
        self.photoData = photoData
        self.createdAt = createdAt
    }
}

/// The quirky feature: a message the outgoing sibling leaves for whoever is next in rotation.
/// `readAt` is the real, honest signal — nil means the recipient has not yet opened it, no
/// matter how long ago it was delivered. The whole circle can see that gap.
struct HandoffNote: Identifiable, Codable, Equatable {
    var id: String
    var fromSiblingID: String
    var toSiblingID: String
    var message: String
    var createdAt: Date
    var readAt: Date?

    init(
        id: String = UUID().uuidString,
        fromSiblingID: String,
        toSiblingID: String,
        message: String,
        createdAt: Date = .now,
        readAt: Date? = nil
    ) {
        self.id = id
        self.fromSiblingID = fromSiblingID
        self.toSiblingID = toSiblingID
        self.message = message
        self.createdAt = createdAt
        self.readAt = readAt
    }

    var isRead: Bool { readAt != nil }
}

/// Free-vs-Pro gating. Free circles top out at 2 siblings total (the person who sets the
/// circle up plus one more); Pro is billed once per family, not per person.
enum CareCircleLimits {
    static let freeMaxSiblings = 2

    static func canAddSibling(currentCount: Int, isPro: Bool) -> Bool {
        isPro || currentCount < freeMaxSiblings
    }

    static func remainingFreeSlots(currentCount: Int) -> Int {
        max(0, freeMaxSiblings - currentCount)
    }
}
