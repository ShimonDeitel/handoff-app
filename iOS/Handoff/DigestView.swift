import SwiftUI

/// Pro feature: condenses the week's post-visit logs into one warm, specific sentence for
/// whichever sibling lives far away, via the shared AI proxy.
struct DigestView: View {
    @EnvironmentObject var careStore: CareCircleStore
    @EnvironmentObject var store: Store
    @State private var showPaywall = false

    private var weekLogs: [VisitLog] {
        DigestPromptBuilder.thisWeek(careStore.visitLogs)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                HandoffColor.canvas.ignoresSafeArea()
                if store.isPro {
                    proContent
                } else {
                    lockedContent
                }
            }
            .navigationTitle("Weekly Digest")
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    private var proContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HandoffCard {
                    Text("This week so far").font(HandoffFont.tag(12)).foregroundStyle(HandoffColor.inkMuted)
                    Text("\(weekLogs.count) visit \(weekLogs.count == 1 ? "note" : "notes") logged")
                        .font(HandoffFont.headline(17))
                        .foregroundStyle(HandoffColor.ink)
                }

                if let digestText = careStore.digestText {
                    HandoffCard {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles").foregroundStyle(HandoffColor.lavender)
                            Text("For the sibling far away").font(HandoffFont.tag(12)).foregroundStyle(HandoffColor.inkMuted)
                        }
                        Text(digestText).font(HandoffFont.body(17)).foregroundStyle(HandoffColor.ink)
                    }
                }

                if let error = careStore.digestErrorMessage {
                    Text(error).font(.footnote).foregroundStyle(HandoffColor.waiting)
                }

                Button {
                    Task { await careStore.generateWeeklyDigest() }
                } label: {
                    HStack {
                        if careStore.isGeneratingDigest { ProgressView().tint(.white) }
                        Text(careStore.isGeneratingDigest ? "Writing…" : (careStore.digestText == nil ? "Generate Weekly Digest" : "Regenerate"))
                    }
                    .frame(maxWidth: .infinity)
                }
                .prominentLavenderButton()
                .disabled(careStore.isGeneratingDigest || weekLogs.isEmpty)

                if weekLogs.isEmpty {
                    Text("Log a visit this week to generate a digest.")
                        .font(.footnote)
                        .foregroundStyle(HandoffColor.inkMuted)
                }
            }
            .padding()
        }
    }

    private var lockedContent: some View {
        VStack(spacing: 18) {
            Image(systemName: "sparkles")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(HandoffColor.lavender)
            Text("Weekly Digest is a Pro feature")
                .font(HandoffFont.headline(18))
                .foregroundStyle(HandoffColor.ink)
            Text("Condense the whole week's visit logs into one warm sentence for whoever lives far away — generated fresh every week.")
                .font(.subheadline)
                .foregroundStyle(HandoffColor.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                Haptics.tap()
                showPaywall = true
            } label: {
                Text("Get Handoff Pro").frame(maxWidth: .infinity)
            }
            .prominentLavenderButton()
            .padding(.horizontal, 40)
        }
    }
}
