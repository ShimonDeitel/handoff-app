import Foundation

/// Who currently holds the baton, in plain terms the UI can bind straight to.
enum TurnStatus: Equatable {
    /// The rotation is caught up: this sibling's turn is active and no handoff is pending.
    case active(siblingID: String)
    /// A handoff was sent but the recipient has not opened it yet — the silent-gap state the
    /// whole circle should see, not just the two siblings involved.
    case waitingOnRead(fromSiblingID: String, toSiblingID: String, sentAt: Date)
}

/// Pure, deterministic rotation + handoff-gating logic. No SwiftUI, no CloudKit — every
/// function takes plain values and returns plain values so it is unit-testable without a
/// container or network.
enum HandoffTurnEngine {

    /// The next index in a fixed-size rotation, wrapping back to 0 after the last sibling.
    /// `count == 0` returns 0 defensively (callers never advance an empty circle).
    static func nextIndex(current: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return (current + 1) % count
    }

    /// Whose turn it officially is right now, given the rotation's current index and the most
    /// recent handoff note addressed to that index's sibling (if any). A `nil` note means the
    /// turn was never explicitly handed off (e.g. the very first turn) and is active by default.
    static func status(currentIndex: Int, siblingIDs: [String], mostRecentNote: HandoffNote?) -> TurnStatus {
        guard siblingIDs.indices.contains(currentIndex) else {
            return .active(siblingID: "")
        }
        let currentID = siblingIDs[currentIndex]
        guard let note = mostRecentNote, note.toSiblingID == currentID else {
            return .active(siblingID: currentID)
        }
        if note.readAt != nil {
            return .active(siblingID: currentID)
        } else {
            return .waitingOnRead(fromSiblingID: note.fromSiblingID, toSiblingID: currentID, sentAt: note.createdAt)
        }
    }

    /// True only once the recipient has actually opened the note — never on delivery alone.
    static func isTurnActive(_ status: TurnStatus) -> Bool {
        if case .active = status { return true }
        return false
    }
}
