import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var careStore: CareCircleStore
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @AppStorage("handoff.theme") private var themeRaw = AppTheme.system.rawValue

    @State private var showPaywall = false
    @State private var showDeleteConfirm = false
    @State private var showAddSibling = false
    @State private var newSiblingName = ""

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return "Handoff \(v)"
    }

    var body: some View {
        NavigationStack {
            Form {
                proSection
                circleSection
                appearanceSection
                dataSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
            .tint(HandoffColor.lavenderDeep)
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .alert("Add a Sibling", isPresented: $showAddSibling) {
                TextField("Name", text: $newSiblingName)
                Button("Add") {
                    Task {
                        _ = await careStore.addSibling(name: newSiblingName)
                        newSiblingName = ""
                    }
                }
                Button("Cancel", role: .cancel) { newSiblingName = "" }
            }
            .alert("Erase All Local Data?", isPresented: $showDeleteConfirm) {
                Button("Erase", role: .destructive) {
                    careStore.deleteAllLocalData()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This clears the circle from this device. Handoff is single-device only right now, so there's no other copy anywhere else.")
            }
        }
    }

    @ViewBuilder
    private var proSection: some View {
        Section {
            if store.isPro {
                HStack {
                    Label("Handoff Pro", systemImage: "person.crop.circle.badge.checkmark")
                    Spacer()
                    Text("Active").foregroundStyle(.secondary)
                }
            } else {
                Button {
                    Haptics.tap(); showPaywall = true
                } label: {
                    HStack {
                        Label("Get Handoff Pro", systemImage: "person.crop.circle.badge.checkmark")
                        Spacer()
                        Text("\(store.displayPrice)/mo").foregroundStyle(.secondary)
                    }
                }
                Button("Restore Purchase") { Task { await store.restore() } }
            }
        } footer: {
            if !store.isPro {
                Text("One subscription covers your whole care circle — unlimited siblings, the AI weekly digest, and full visit-log history.")
            }
        }
    }

    @ViewBuilder
    private var circleSection: some View {
        Section("Care Circle") {
            if let circle = careStore.circle {
                HStack {
                    Text("Caring for")
                    Spacer()
                    Text(circle.parentName).foregroundStyle(.secondary)
                }
            }
            if !careStore.siblings.isEmpty {
                Picker("You are", selection: $careStore.mySiblingID) {
                    ForEach(careStore.siblings) { sibling in
                        Text(sibling.name).tag(Optional(sibling.id))
                    }
                }
            }
            ForEach(careStore.siblings) { sibling in
                HStack(spacing: 10) {
                    Circle().fill(HandoffColor.sibling(sibling.orderIndex)).frame(width: 10, height: 10)
                    Text(sibling.name)
                    Spacer()
                    if sibling.id == careStore.mySiblingID {
                        Text("You").font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            if careStore.canAddSibling {
                Button {
                    Haptics.tap(); showAddSibling = true
                } label: {
                    Label("Add Sibling", systemImage: "person.badge.plus")
                }
            } else {
                Button {
                    Haptics.tap(); showPaywall = true
                } label: {
                    Label("Unlock More Siblings with Pro", systemImage: "lock.fill")
                }
            }
            HStack {
                Label("Invite Siblings", systemImage: "square.and.arrow.up")
                Spacer()
                Text("Multi-device sync coming soon").font(.footnote).foregroundStyle(.secondary)
            }
            .foregroundStyle(.secondary)
        }
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Theme", selection: $themeRaw) {
                ForEach(AppTheme.allCases) { Text($0.label).tag($0.rawValue) }
            }
            .pickerStyle(.segmented)
        }
    }

    private var dataSection: some View {
        Section {
            Button("Erase Local Data", role: .destructive) { showDeleteConfirm = true }
        } header: {
            Text("Data & Privacy")
        } footer: {
            Text("Visit logs, handoff notes, and circle details stay on this device only — Handoff is single-device for now, with no server database and no cross-device sync. The weekly digest sends that week's notes to a stateless AI service to write one sentence; nothing is stored there afterward.")
        }
    }

    private var aboutSection: some View {
        Section {
            Link("Privacy Policy", destination: URL(string: "https://shimondeitel.github.io/handoff-site/privacy.html")!)
            Link("Terms of Use", destination: URL(string: "https://shimondeitel.github.io/handoff-site/terms.html")!)
        } footer: {
            Text(version).frame(maxWidth: .infinity, alignment: .center).padding(.top, 4)
        }
    }
}
