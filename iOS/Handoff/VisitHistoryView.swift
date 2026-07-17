import SwiftUI

/// Every logged visit/call, most recent first. Free circles see only the most recent entries;
/// Pro unlocks the full history for the whole family.
struct VisitHistoryView: View {
    @EnvironmentObject var careStore: CareCircleStore
    @EnvironmentObject var store: Store
    @State private var showPaywall = false

    static let freeVisibleCount = 5

    private var sortedLogs: [VisitLog] {
        careStore.visitLogs.sorted { $0.createdAt > $1.createdAt }
    }

    private var visibleLogs: [VisitLog] {
        store.isPro ? sortedLogs : Array(sortedLogs.prefix(Self.freeVisibleCount))
    }

    private var hiddenCount: Int {
        max(0, sortedLogs.count - visibleLogs.count)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                HandoffColor.canvas.ignoresSafeArea()
                if sortedLogs.isEmpty {
                    ContentUnavailableView(
                        "No Visits Yet",
                        systemImage: "heart.text.square",
                        description: Text("Log a visit or call from the Circle tab and it'll show up here for everyone.")
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(visibleLogs) { log in
                                VisitLogRow(log: log, siblingName: name(for: log.siblingID))
                            }
                            if hiddenCount > 0 {
                                Button {
                                    Haptics.tap()
                                    showPaywall = true
                                } label: {
                                    Label("Unlock \(hiddenCount) Earlier \(hiddenCount == 1 ? "Visit" : "Visits") with Pro", systemImage: "lock.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .stonePanelButton()
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Visits")
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    private func name(for id: String) -> String {
        careStore.siblings.first(where: { $0.id == id })?.name ?? "Someone"
    }
}

private struct VisitLogRow: View {
    let log: VisitLog
    let siblingName: String

    var body: some View {
        HandoffCard {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(siblingName).font(HandoffFont.headline(15)).foregroundStyle(HandoffColor.ink)
                        Spacer()
                        Text(log.createdAt, style: .relative)
                            .font(.footnote)
                            .foregroundStyle(HandoffColor.inkMuted)
                    }
                    Text(log.note).font(HandoffFont.body(15)).foregroundStyle(HandoffColor.ink)
                    if let photoData = log.photoData, let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 140)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
        }
    }
}
