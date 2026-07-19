import SwiftUI

/// First-launch setup: name the parent being cared for and yourself, which creates the shared
/// care circle. Inviting siblings happens afterward from Settings, once the circle exists.
struct OnboardingView: View {
    @EnvironmentObject var careStore: CareCircleStore
    @State private var parentName = ""
    @State private var myName = ""
    @State private var isCreating = false

    var body: some View {
        ZStack {
            HandoffColor.canvas.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 10) {
                        Circle()
                            .fill(HandoffColor.lavender.opacity(0.18))
                            .frame(width: 88, height: 88)
                            .overlay(
                                Image(systemName: "circle.grid.3x3.fill")
                                    .font(.system(size: 32, weight: .semibold))
                                    .foregroundStyle(HandoffColor.lavender)
                            )
                        Text("Handoff").font(HandoffFont.title(30)).foregroundStyle(HandoffColor.ink)
                        Text("A shared space for siblings caring for a parent together.")
                            .font(.subheadline)
                            .foregroundStyle(HandoffColor.inkMuted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(.top, 40)

                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Who are you caring for?").font(HandoffFont.tag(13)).foregroundStyle(HandoffColor.inkMuted)
                            TextField("Parent's name", text: $parentName)
                                .textFieldStyle(.plain)
                                .padding(12)
                                .background(HandoffColor.panel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(HandoffColor.hairline, lineWidth: 1))
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("What's your name?").font(HandoffFont.tag(13)).foregroundStyle(HandoffColor.inkMuted)
                            TextField("Your name", text: $myName)
                                .textFieldStyle(.plain)
                                .padding(12)
                                .background(HandoffColor.panel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(HandoffColor.hairline, lineWidth: 1))
                        }
                    }
                    .padding(.horizontal)

                    Button {
                        Task { await create() }
                    } label: {
                        HStack {
                            if isCreating { ProgressView().tint(.white) }
                            Text(isCreating ? "Setting up…" : "Create Care Circle")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .prominentLavenderButton()
                    .padding(.horizontal)
                    .disabled(!canCreate || isCreating)

                    Text("You can invite your siblings once the circle is set up, from Settings.")
                        .font(.footnote)
                        .foregroundStyle(HandoffColor.inkMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .dismissKeyboardOnTap()
    }

    private var canCreate: Bool {
        !parentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !myName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func create() async {
        isCreating = true
        await careStore.createCircle(parentName: parentName, myName: myName)
        isCreating = false
        Haptics.success()
    }
}
