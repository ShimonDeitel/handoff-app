import SwiftUI

/// The recipient's side of the quirky feature: the note must be opened here and the "Mark as
/// Read" button tapped for the turn to officially start. Delivery alone never counts.
struct HandoffNoteReadView: View {
    @EnvironmentObject var careStore: CareCircleStore
    @Environment(\.dismiss) private var dismiss
    @State private var didMarkRead = false

    private var pendingNote: HandoffNote? {
        guard let mySiblingID = careStore.mySiblingID else { return nil }
        return careStore.mostRecentNote(to: mySiblingID)
    }

    private var fromName: String {
        guard let note = pendingNote else { return "Someone" }
        return careStore.siblings.first(where: { $0.id == note.fromSiblingID })?.name ?? "Someone"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                HandoffColor.canvas.ignoresSafeArea()
                VStack(spacing: 20) {
                    Image(systemName: didMarkRead ? "checkmark.seal.fill" : "envelope.open.fill")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(didMarkRead ? HandoffColor.good : HandoffColor.lavender)
                        .padding(.top, 24)

                    Text("From \(fromName)")
                        .font(HandoffFont.headline(18))
                        .foregroundStyle(HandoffColor.inkMuted)

                    HandoffCard {
                        Text(pendingNote?.message ?? "No handoff note is waiting for you.")
                            .font(HandoffFont.body(17))
                            .foregroundStyle(HandoffColor.ink)
                    }
                    .padding(.horizontal)

                    if didMarkRead {
                        Text("Your turn is now officially active.")
                            .font(.footnote)
                            .foregroundStyle(HandoffColor.good)
                    }

                    Spacer()

                    if !didMarkRead {
                        Button {
                            Task {
                                await careStore.markPendingNoteRead()
                                didMarkRead = true
                                Haptics.success()
                            }
                        } label: {
                            Label("I've Got It — Mark as Read", systemImage: "checkmark.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .prominentLavenderButton()
                        .padding(.horizontal)
                        .disabled(pendingNote == nil)
                    }
                }
                .padding(.bottom, 24)
            }
            .navigationTitle("Handoff Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } }
            }
        }
    }
}
