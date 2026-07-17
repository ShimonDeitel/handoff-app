import SwiftUI

struct PaywallView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var working = false
    @State private var restoreMessage: String?

    private let benefits: [(String, String, String)] = [
        ("person.3.fill", "Unlimited siblings", "Free circles top out at 2 members. Pro removes the cap for the whole family."),
        ("sparkles", "AI weekly digest", "One warm, specific sentence condensing the week for whoever lives far away."),
        ("clock.arrow.circlepath", "Full visit-log history", "See every visit ever logged, not just the last few.")
    ]

    var body: some View {
        ZStack {
            HandoffColor.canvas.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 8) {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .font(.system(size: 40, weight: .semibold))
                            .foregroundStyle(HandoffColor.lavender)
                        Text("Handoff Pro").font(HandoffFont.title(30))
                            .foregroundStyle(HandoffColor.ink)
                        Text("\(store.displayPrice) / month, billed once for your whole family. Cancel anytime.")
                            .font(.subheadline)
                            .foregroundStyle(HandoffColor.inkMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(.top, 28)

                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(benefits, id: \.0) { item in
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: item.0)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(HandoffColor.lavender)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.1).font(HandoffFont.headline(16))
                                        .foregroundStyle(HandoffColor.ink)
                                    Text(item.2).font(.subheadline).foregroundStyle(HandoffColor.inkMuted)
                                }
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .padding(16)
                    .background(HandoffColor.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(HandoffColor.hairline, lineWidth: 1)
                    )
                    .padding(.horizontal)

                    VStack(spacing: 12) {
                        Button { Task { await buy() } } label: {
                            HStack {
                                if working { ProgressView().tint(.white) }
                                Text(working ? "Starting…" : "Start Handoff Pro · \(store.displayPrice)/mo")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 6)
                        }
                        .prominentLavenderButton()
                        .accessibilityIdentifier("paywall-subscribe")
                        .disabled(working)

                        Button("Restore Purchase") { Task { await restore() } }
                            .font(.subheadline).tint(HandoffColor.inkMuted)

                        if let restoreMessage {
                            Text(restoreMessage).font(.footnote).foregroundStyle(HandoffColor.inkMuted)
                        }

                        Text("Auto-renewable subscription, billed monthly to your Apple ID. One subscription covers everyone in the circle. Manage or cancel anytime in Settings.")
                            .font(.footnote).foregroundStyle(HandoffColor.inkMuted)
                            .multilineTextAlignment(.center).padding(.top, 4)
                    }
                    .padding(.horizontal).padding(.bottom, 30)
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill").font(.title2)
                    .foregroundStyle(HandoffColor.inkMuted).padding()
            }
            .accessibilityLabel("Close")
            .accessibilityIdentifier("paywall-close")
        }
        .onChange(of: store.isPro) { _, newValue in if newValue { dismiss() } }
    }

    private func buy() async {
        working = true
        let ok = await store.purchase()
        working = false
        if ok { Haptics.success(); dismiss() }
    }

    private func restore() async {
        await store.restore()
        if store.isPro { Haptics.success(); dismiss() }
        else { restoreMessage = "No previous purchase found on this Apple ID." }
    }
}
