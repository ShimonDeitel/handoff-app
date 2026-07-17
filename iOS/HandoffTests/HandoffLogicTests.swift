import XCTest
import CoreGraphics
import CloudKit
@testable import Handoff

/// Deterministic core-logic tests: rotation/handoff gating, radial trigonometry, free-tier
/// gating, this-week filtering, digest prompt assembly, and CKRecord round-trips. No network,
/// no CloudKit container, no UI — everything here is hand-verified plain values.
final class HandoffLogicTests: XCTestCase {

    private func day(_ n: Int) -> Date {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 1; comps.day = 1
        let cal = Calendar(identifier: .gregorian)
        let base = cal.date(from: comps)!
        return cal.date(byAdding: .day, value: n, to: base)!
    }

    // MARK: Rotation

    func testNextIndexWrapsAroundToZero() {
        XCTAssertEqual(HandoffTurnEngine.nextIndex(current: 0, count: 3), 1)
        XCTAssertEqual(HandoffTurnEngine.nextIndex(current: 1, count: 3), 2)
        XCTAssertEqual(HandoffTurnEngine.nextIndex(current: 2, count: 3), 0)
    }

    func testNextIndexWithEmptyCircleReturnsZero() {
        XCTAssertEqual(HandoffTurnEngine.nextIndex(current: 0, count: 0), 0)
    }

    // MARK: Turn status / the quirky handoff-read gate

    func testTurnActiveWhenNoHandoffNoteExistsYet() {
        // Fresh circle: nobody has ever sent a handoff, so the first sibling's turn is active
        // by default rather than stuck waiting on a note that was never sent.
        let status = HandoffTurnEngine.status(currentIndex: 0, siblingIDs: ["A", "B"], mostRecentNote: nil)
        XCTAssertEqual(status, .active(siblingID: "A"))
    }

    func testTurnWaitingWhenNoteSentButUnread() {
        let note = HandoffNote(fromSiblingID: "A", toSiblingID: "B", message: "hi", createdAt: day(1), readAt: nil)
        let status = HandoffTurnEngine.status(currentIndex: 1, siblingIDs: ["A", "B"], mostRecentNote: note)
        XCTAssertEqual(status, .waitingOnRead(fromSiblingID: "A", toSiblingID: "B", sentAt: day(1)))
        XCTAssertFalse(HandoffTurnEngine.isTurnActive(status))
    }

    func testTurnBecomesActiveOnceNoteIsRead() {
        let note = HandoffNote(fromSiblingID: "A", toSiblingID: "B", message: "hi", createdAt: day(1), readAt: day(1))
        let status = HandoffTurnEngine.status(currentIndex: 1, siblingIDs: ["A", "B"], mostRecentNote: note)
        XCTAssertEqual(status, .active(siblingID: "B"))
        XCTAssertTrue(HandoffTurnEngine.isTurnActive(status))
    }

    // MARK: Radial layout trigonometry (the animation hook's math)

    func testRadialPositionsAtFourCardinalPoints() {
        let center = CGPoint(x: 100, y: 100)
        let radius: CGFloat = 50
        // Index 0 of 4 starts at 12 o'clock: straight up from center.
        let top = RadialLayout.position(index: 0, count: 4, center: center, radius: radius)
        XCTAssertEqual(top.x, 100, accuracy: 0.001)
        XCTAssertEqual(top.y, 50, accuracy: 0.001)
        // Index 1 of 4 is a quarter turn clockwise: 3 o'clock (screen y grows downward).
        let right = RadialLayout.position(index: 1, count: 4, center: center, radius: radius)
        XCTAssertEqual(right.x, 150, accuracy: 0.001)
        XCTAssertEqual(right.y, 100, accuracy: 0.001)
        // Index 2 of 4: 6 o'clock.
        let bottom = RadialLayout.position(index: 2, count: 4, center: center, radius: radius)
        XCTAssertEqual(bottom.x, 100, accuracy: 0.001)
        XCTAssertEqual(bottom.y, 150, accuracy: 0.001)
        // Index 3 of 4: 9 o'clock.
        let left = RadialLayout.position(index: 3, count: 4, center: center, radius: radius)
        XCTAssertEqual(left.x, 50, accuracy: 0.001)
        XCTAssertEqual(left.y, 100, accuracy: 0.001)
    }

    func testQuadraticPointEndpointsMatchP0AndP1() {
        let p0 = CGPoint(x: 0, y: 0)
        let control = CGPoint(x: 50, y: -50)
        let p1 = CGPoint(x: 100, y: 0)
        let start = RadialLayout.quadraticPoint(0, p0: p0, control: control, p1: p1)
        let end = RadialLayout.quadraticPoint(1, p0: p0, control: control, p1: p1)
        XCTAssertEqual(start.x, p0.x, accuracy: 0.001)
        XCTAssertEqual(start.y, p0.y, accuracy: 0.001)
        XCTAssertEqual(end.x, p1.x, accuracy: 0.001)
        XCTAssertEqual(end.y, p1.y, accuracy: 0.001)
        // Midpoint of a symmetric curve like this one sits exactly halfway across and above the line.
        let mid = RadialLayout.quadraticPoint(0.5, p0: p0, control: control, p1: p1)
        XCTAssertEqual(mid.x, 50, accuracy: 0.001)
        XCTAssertEqual(mid.y, -25, accuracy: 0.001)
    }

    // MARK: Free-tier gating

    func testFreeTierBlocksAddingBeyondTwoSiblings() {
        XCTAssertTrue(CareCircleLimits.canAddSibling(currentCount: 1, isPro: false))
        XCTAssertFalse(CareCircleLimits.canAddSibling(currentCount: 2, isPro: false))
    }

    func testProUnlocksUnlimitedSiblings() {
        XCTAssertTrue(CareCircleLimits.canAddSibling(currentCount: 50, isPro: true))
    }

    func testRemainingFreeSlotsNeverGoesNegative() {
        XCTAssertEqual(CareCircleLimits.remainingFreeSlots(currentCount: 0), 2)
        XCTAssertEqual(CareCircleLimits.remainingFreeSlots(currentCount: 2), 0)
        XCTAssertEqual(CareCircleLimits.remainingFreeSlots(currentCount: 5), 0)
    }

    // MARK: Digest: this-week filtering + prompt assembly

    func testThisWeekFiltersOutOlderLogs() {
        let now = day(10)
        let logs = [
            VisitLog(siblingID: "A", note: "recent", createdAt: day(9)),
            VisitLog(siblingID: "A", note: "too old", createdAt: day(1))
        ]
        let result = DigestPromptBuilder.thisWeek(logs, now: now)
        XCTAssertEqual(result.map(\.note), ["recent"])
    }

    func testDigestPromptIncludesParentNameAndEachSiblingsNote() {
        let logs = [
            VisitLog(siblingID: "a-id", note: "took Mom to PT", createdAt: day(1)),
            VisitLog(siblingID: "b-id", note: "called and she sounded great", createdAt: day(2))
        ]
        let prompt = DigestPromptBuilder.buildUserPrompt(
            parentName: "Rose",
            logs: logs,
            siblingNames: ["a-id": "Priya", "b-id": "Sam"]
        )
        XCTAssertTrue(prompt.contains("Rose"))
        XCTAssertTrue(prompt.contains("Priya: took Mom to PT"))
        XCTAssertTrue(prompt.contains("Sam: called and she sounded great"))
    }

    func testDigestPromptHandlesNoLogsThisWeek() {
        let prompt = DigestPromptBuilder.buildUserPrompt(parentName: "Rose", logs: [], siblingNames: [:])
        XCTAssertTrue(prompt.contains("No visit notes were logged this week"))
    }

    // MARK: CKRecord round-trips (pure model <-> record mapping, no network)

    func testSiblingRecordRoundTrip() {
        let sibling = Sibling(id: "sib-1", name: "Priya", orderIndex: 2, joinedAt: day(3))
        let zoneID = CKRecordZone.ID(zoneName: "CareCircleZone", ownerName: CKCurrentUserDefaultName)
        let record = sibling.toRecord(zoneID: zoneID)
        let decoded = Sibling(record: record)
        XCTAssertEqual(decoded?.id, "sib-1")
        XCTAssertEqual(decoded?.name, "Priya")
        XCTAssertEqual(decoded?.orderIndex, 2)
    }

    func testHandoffNoteRecordRoundTripPreservesNilReadAt() {
        let note = HandoffNote(id: "note-1", fromSiblingID: "A", toSiblingID: "B", message: "Mom's appointment is Tuesday", createdAt: day(4), readAt: nil)
        let zoneID = CKRecordZone.ID(zoneName: "CareCircleZone", ownerName: CKCurrentUserDefaultName)
        let record = note.toRecord(zoneID: zoneID)
        let decoded = HandoffNote(record: record)
        XCTAssertEqual(decoded?.message, "Mom's appointment is Tuesday")
        XCTAssertNil(decoded?.readAt)
    }

    func testHandoffNoteRecordRoundTripPreservesReadAt() {
        let note = HandoffNote(id: "note-2", fromSiblingID: "A", toSiblingID: "B", message: "hi", createdAt: day(4), readAt: day(5))
        let zoneID = CKRecordZone.ID(zoneName: "CareCircleZone", ownerName: CKCurrentUserDefaultName)
        let record = note.toRecord(zoneID: zoneID)
        let decoded = HandoffNote(record: record)
        XCTAssertNotNil(decoded?.readAt)
        XCTAssertEqual(decoded?.readAt, day(5))
    }
}
