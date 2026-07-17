import SwiftUI

/// The outgoing sibling composes the note the next sibling in rotation must open and read
/// before their turn becomes official.
struct SendHandoffView: View {
    @EnvironmentObject var careStore: CareCircleStore
    @Environment(\.dismiss) private var dismiss

    @State private var message = ""
    @State private var isSending = false

    private var nextSibling: Sibling? {
        guard let circle = careStore.circle, !careStore.siblings.isEmpty else { return nil }
        let ordered = careStore.siblings.sorted { $0.orderIndex < $1.orderIndex }
        let nextIndex = HandoffTurnEngine.nextIndex(current: circle.currentTurnIndex, count: ordered.count)
        return ordered.indices.contains(nextIndex) ? ordered[nextIndex] : nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                HandoffColor.canvas.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 18) {
                    if let nextSibling {
                        HStack(spacing: 12) {
                            NodeAvatarView(
                                initials: nextSibling.initials,
                                photoData: nextSibling.photoData,
                                ringColor: HandoffColor.sibling(nextSibling.orderIndex),
                                diameter: 48
                            )
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Handing off to").font(.footnote).foregroundStyle(HandoffColor.inkMuted)
                                Text(nextSibling.name).font(HandoffFont.headline(18)).foregroundStyle(HandoffColor.ink)
                            }
                            Spacer()
                        }
                    }

                    Text("Leave anything they should know before their turn starts — meds, appointments, how the week's been.")
                        .font(.footnote)
                        .foregroundStyle(HandoffColor.inkMuted)

                    TextEditor(text: $message)
                        .frame(minHeight: 140)
                        .padding(10)
                        .scrollContentBackground(.hidden)
                        .background(HandoffColor.panel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(HandoffColor.hairline, lineWidth: 1)
                        )

                    Text("\(nextSibling?.name ?? "They") will need to actually open and read this before the turn officially starts — the whole circle sees a waiting banner until then.")
                        .font(.footnote)
                        .foregroundStyle(HandoffColor.waiting)

                    Button {
                        Task { await send() }
                    } label: {
                        HStack {
                            if isSending { ProgressView().tint(.white) }
                            Text(isSending ? "Sending…" : "Send Handoff")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .prominentLavenderButton()
                    .disabled(isSending || nextSibling == nil)

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Hand Off")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            }
        }
    }

    private func send() async {
        isSending = true
        await careStore.sendHandoff(message: message)
        isSending = false
        Haptics.success()
        dismiss()
    }
}
