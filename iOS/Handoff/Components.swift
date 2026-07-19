import SwiftUI
import UIKit

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func soft() { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func click() { UISelectionFeedbackGenerator().selectionChanged() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}

/// Primary CTA — a solid lavender bar.
struct FilledLavenderButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(HandoffFont.value(16))
            .foregroundStyle(.white)
            .padding(.vertical, 13)
            .padding(.horizontal, 22)
            .frame(maxWidth: .infinity)
            .background(HandoffColor.lavender, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Secondary — a stone-panel button with a hairline edge.
struct StonePanelButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(HandoffFont.tag(15))
            .foregroundStyle(HandoffColor.ink)
            .padding(.vertical, 12)
            .padding(.horizontal, 18)
            .background(HandoffColor.panel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(HandoffColor.hairline, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension View {
    func prominentLavenderButton() -> some View { buttonStyle(FilledLavenderButtonStyle()) }
    func stonePanelButton() -> some View { buttonStyle(StonePanelButtonStyle()) }

    /// Lets a tap anywhere on this view resign the keyboard, without swallowing taps meant for
    /// buttons/controls inside it (hence `simultaneousGesture` rather than a plain gesture).
    func dismissKeyboardOnTap() -> some View {
        simultaneousGesture(
            TapGesture().onEnded {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        )
    }
}

/// A grouped card container used across Circle/Visits/Digest.
struct HandoffCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 14) { content }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HandoffColor.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(HandoffColor.hairline, lineWidth: 1)
            )
    }
}

/// A photo-or-initials circle node — used for both the parent avatar and every sibling node,
/// in the constellation layout and in plain lists alike.
struct NodeAvatarView: View {
    let initials: String
    let photoData: Data?
    let ringColor: Color
    var diameter: CGFloat = 56

    var body: some View {
        ZStack {
            Circle()
                .fill(HandoffColor.panel)
            if let photoData, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
            } else {
                Text(initials)
                    .font(.system(size: diameter * 0.34, weight: .semibold, design: .rounded))
                    .foregroundStyle(ringColor)
            }
        }
        .frame(width: diameter, height: diameter)
        .overlay(Circle().strokeBorder(ringColor, lineWidth: 2.5))
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
    }
}

/// The "still waiting for Sam to read the handoff" banner — the visible closing of the silent
/// gap, shown to the whole circle whenever a handoff note has been sent but not yet opened.
struct WaitingBanner: View {
    let fromName: String
    let toName: String
    let sentAt: Date

    private var relative: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: sentAt, relativeTo: .now)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "hourglass")
                .foregroundStyle(HandoffColor.waiting)
                .font(.system(size: 16, weight: .semibold))
            VStack(alignment: .leading, spacing: 2) {
                Text("Still waiting for \(toName) to read the handoff")
                    .font(HandoffFont.tag(14))
                    .foregroundStyle(HandoffColor.ink)
                Text("\(fromName) sent it \(relative) — \(toName)'s turn isn't official yet.")
                    .font(.footnote)
                    .foregroundStyle(HandoffColor.inkMuted)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(HandoffColor.waiting.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(HandoffColor.waiting.opacity(0.35), lineWidth: 1)
        )
    }
}
