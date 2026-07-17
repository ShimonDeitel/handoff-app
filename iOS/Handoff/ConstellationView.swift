import SwiftUI

/// The animation-hook screen: siblings as small photo-nodes orbiting a center parent avatar,
/// connected by thin constellation arcs. Logging a visit sends a glowing dot from that
/// sibling's node to the center, then back out to every other node — a visible, literal
/// "the update reached the whole circle."
struct ConstellationView: View {
    @EnvironmentObject var careStore: CareCircleStore
    @EnvironmentObject var store: Store

    @State private var showLogVisit = false
    @State private var showSettings = false
    @State private var showSendHandoff = false
    @State private var showReadHandoff = false
    @State private var selectedSibling: Sibling?
    @State private var activePulse: PulseEvent?

    private let pulseDuration: TimeInterval = 1.6

    var body: some View {
        NavigationStack {
            ZStack {
                HandoffColor.canvas.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 18) {
                        constellationArea
                        turnStatusSection
                        actionButtons
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Handoff")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.tap()
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showLogVisit) { LogVisitView() }
            .sheet(isPresented: $showSendHandoff) { SendHandoffView() }
            .sheet(isPresented: $showReadHandoff) { HandoffNoteReadView() }
            .sheet(item: $selectedSibling) { sibling in
                SiblingDetailSheet(sibling: sibling)
            }
        }
        .onChange(of: careStore.pulseEvent) { _, newValue in
            guard let newValue else { return }
            activePulse = newValue
        }
        .task { await careStore.refreshFromCloud() }
    }

    // MARK: Constellation

    private var constellationArea: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let center = CGPoint(x: size.width / 2, y: size.height / 2 - 10)
            let radius = min(size.width, size.height) / 2 * 0.66
            let ordered = careStore.siblings.sorted { $0.orderIndex < $1.orderIndex }

            ZStack {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: false)) { timeline in
                    Canvas { context, _ in
                        drawArcs(context: context, center: center, radius: radius, count: ordered.count)
                        if let activePulse {
                            let elapsed = timeline.date.timeIntervalSince(activePulse.firedAt)
                            if elapsed >= 0, elapsed < pulseDuration {
                                drawPulse(context: context, center: center, radius: radius, ordered: ordered, origin: activePulse.originSiblingID, elapsed: elapsed)
                            }
                        }
                    }
                }
                .allowsHitTesting(false)

                NodeAvatarView(
                    initials: String(careStore.circle?.parentName.prefix(1) ?? "?").uppercased(),
                    photoData: careStore.circle?.parentPhotoData,
                    ringColor: HandoffColor.stoneDeep,
                    diameter: 78
                )
                .position(center)

                Text(careStore.circle?.parentName ?? "")
                    .font(HandoffFont.tag(12))
                    .foregroundStyle(HandoffColor.inkMuted)
                    .position(x: center.x, y: center.y + 54)

                ForEach(Array(ordered.enumerated()), id: \.element.id) { index, sibling in
                    let point = RadialLayout.position(index: index, count: ordered.count, center: center, radius: radius)
                    siblingNode(sibling, isCurrentTurn: isCurrentTurnHolder(sibling))
                        .position(point)
                }
            }
        }
        .frame(height: 300)
        .padding(.top, 4)
    }

    private func siblingNode(_ sibling: Sibling, isCurrentTurn: Bool) -> some View {
        VStack(spacing: 6) {
            NodeAvatarView(
                initials: sibling.initials,
                photoData: sibling.photoData,
                ringColor: HandoffColor.sibling(sibling.orderIndex),
                diameter: isCurrentTurn ? 58 : 50
            )
            Text(sibling.name)
                .font(HandoffFont.tag(11))
                .foregroundStyle(HandoffColor.ink)
                .lineLimit(1)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            Haptics.click()
            selectedSibling = sibling
        }
    }

    // MARK: Canvas drawing

    private func drawArcs(context: GraphicsContext, center: CGPoint, radius: CGFloat, count: Int) {
        guard count > 0 else { return }
        for index in 0..<count {
            let point = RadialLayout.position(index: index, count: count, center: center, radius: radius)
            var path = Path()
            path.move(to: center)
            let control = RadialLayout.bulgeControlPoint(from: center, to: point, center: center)
            path.addQuadCurve(to: point, control: control)
            context.stroke(path, with: .color(HandoffColor.lavender.opacity(0.26)), lineWidth: 1.3)
        }
    }

    private func drawPulse(
        context: GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        ordered: [Sibling],
        origin: String,
        elapsed: TimeInterval
    ) {
        guard let originIndex = ordered.firstIndex(where: { $0.id == origin }) else { return }
        let originPoint = RadialLayout.position(index: originIndex, count: ordered.count, center: center, radius: radius)
        let half = pulseDuration / 2

        if elapsed < half {
            let t = CGFloat(elapsed / half)
            let control = RadialLayout.bulgeControlPoint(from: originPoint, to: center, center: center)
            let point = RadialLayout.quadraticPoint(t, p0: originPoint, control: control, p1: center)
            drawGlow(context: context, at: point)
        } else {
            let t = CGFloat((elapsed - half) / half)
            for (index, sibling) in ordered.enumerated() where sibling.id != origin {
                let target = RadialLayout.position(index: index, count: ordered.count, center: center, radius: radius)
                let control = RadialLayout.bulgeControlPoint(from: center, to: target, center: center)
                let point = RadialLayout.quadraticPoint(t, p0: center, control: control, p1: target)
                drawGlow(context: context, at: point)
            }
        }
    }

    private func drawGlow(context: GraphicsContext, at point: CGPoint) {
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: 6))
            layer.fill(
                Path(ellipseIn: CGRect(x: point.x - 8, y: point.y - 8, width: 16, height: 16)),
                with: .color(HandoffColor.glow.opacity(0.9))
            )
        }
        context.fill(
            Path(ellipseIn: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)),
            with: .color(.white)
        )
    }

    // MARK: Status + actions

    @ViewBuilder
    private var turnStatusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch careStore.turnStatus {
            case .active(let siblingID):
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(HandoffColor.good)
                    Text("\(name(for: siblingID))'s turn is active")
                        .font(HandoffFont.tag(14))
                        .foregroundStyle(HandoffColor.ink)
                    Spacer()
                }
            case .waitingOnRead(let fromID, let toID, let sentAt):
                WaitingBanner(fromName: name(for: fromID), toName: name(for: toID), sentAt: sentAt)
            }

            if careStore.isMyTurnPendingRead {
                Button {
                    Haptics.tap()
                    showReadHandoff = true
                } label: {
                    Label("Open Your Handoff Note", systemImage: "envelope.open.fill")
                        .frame(maxWidth: .infinity)
                }
                .prominentLavenderButton()
            }

            if let message = careStore.syncErrorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(HandoffColor.inkMuted)
            }
        }
        .padding(.horizontal)
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button {
                Haptics.tap()
                showLogVisit = true
            } label: {
                Label("Log a Visit", systemImage: "heart.text.square.fill")
                    .frame(maxWidth: .infinity)
            }
            .prominentLavenderButton()
            .disabled(careStore.mySiblingID == nil)
            .accessibilityIdentifier("log-visit-button")

            if isMyTurn {
                Button {
                    Haptics.tap()
                    showSendHandoff = true
                } label: {
                    Label("Hand Off to Next", systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity)
                }
                .stonePanelButton()
            }
        }
        .padding(.horizontal)
    }

    private var isMyTurn: Bool {
        guard case .active(let id) = careStore.turnStatus else { return false }
        return id == careStore.mySiblingID
    }

    private func isCurrentTurnHolder(_ sibling: Sibling) -> Bool {
        switch careStore.turnStatus {
        case .active(let id): return id == sibling.id
        case .waitingOnRead(_, let toID, _): return toID == sibling.id
        }
    }

    private func name(for id: String) -> String {
        careStore.siblings.first(where: { $0.id == id })?.name ?? "Someone"
    }
}

/// A lightweight tap-through profile for one sibling node: name, whether it's you, and their
/// most recent visit note.
private struct SiblingDetailSheet: View {
    @EnvironmentObject var careStore: CareCircleStore
    @Environment(\.dismiss) private var dismiss
    let sibling: Sibling

    private var lastVisit: VisitLog? {
        careStore.visitLogs.filter { $0.siblingID == sibling.id }.max { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                NodeAvatarView(
                    initials: sibling.initials,
                    photoData: sibling.photoData,
                    ringColor: HandoffColor.sibling(sibling.orderIndex),
                    diameter: 84
                )
                Text(sibling.name).font(HandoffFont.title(24)).foregroundStyle(HandoffColor.ink)
                if sibling.id == careStore.mySiblingID {
                    Text("This is you").font(HandoffFont.tag(13)).foregroundStyle(HandoffColor.lavenderDeep)
                }
                if let lastVisit {
                    HandoffCard {
                        Text("Last visit").font(HandoffFont.tag(12)).foregroundStyle(HandoffColor.inkMuted)
                        Text(lastVisit.note).font(HandoffFont.body(15)).foregroundStyle(HandoffColor.ink)
                        Text(lastVisit.createdAt, style: .relative).font(.footnote).foregroundStyle(HandoffColor.inkMuted)
                    }
                    .padding(.horizontal)
                } else {
                    Text("No visits logged yet.").font(.footnote).foregroundStyle(HandoffColor.inkMuted)
                }
                Spacer()
            }
            .padding(.top, 24)
            .background(HandoffColor.canvas.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } }
            }
        }
    }
}
