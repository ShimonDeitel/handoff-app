import PhotosUI
import SwiftUI

/// Quick post-visit/post-call log: a short note plus an optional photo. Saving triggers the
/// constellation's traveling-glow animation via `CareCircleStore.logVisit`.
struct LogVisitView: View {
    @EnvironmentObject var careStore: CareCircleStore
    @Environment(\.dismiss) private var dismiss

    @State private var note = ""
    @State private var pickerItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ZStack {
                HandoffColor.canvas.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("How did it go?")
                            .font(HandoffFont.title(24))
                            .foregroundStyle(HandoffColor.ink)

                        TextEditor(text: $note)
                            .frame(minHeight: 120)
                            .padding(10)
                            .scrollContentBackground(.hidden)
                            .background(HandoffColor.panel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(HandoffColor.hairline, lineWidth: 1)
                            )
                            .overlay(alignment: .topLeading) {
                                if note.isEmpty {
                                    Text("Mom had a good afternoon, ate well, we walked in the garden…")
                                        .font(HandoffFont.body(15))
                                        .foregroundStyle(HandoffColor.inkMuted)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 18)
                                        .allowsHitTesting(false)
                                }
                            }

                        if let photoData, let uiImage = UIImage(data: photoData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(alignment: .topTrailing) {
                                    Button {
                                        self.photoData = nil
                                        pickerItem = nil
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.white, .black.opacity(0.5))
                                            .font(.title2)
                                    }
                                    .padding(8)
                                }
                        }

                        PhotosPicker(selection: $pickerItem, matching: .images) {
                            Label(photoData == nil ? "Add a Photo" : "Change Photo", systemImage: "photo.on.rectangle")
                        }
                        .stonePanelButton()

                        Button {
                            Task { await save() }
                        } label: {
                            HStack {
                                if isSaving { ProgressView().tint(.white) }
                                Text(isSaving ? "Saving…" : "Save Visit Log")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .prominentLavenderButton()
                        .disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .dismissKeyboardOnTap()
            .navigationTitle("Log a Visit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            }
            .onChange(of: pickerItem) { _, newItem in
                Task {
                    if let newItem, let data = try? await newItem.loadTransferable(type: Data.self) {
                        photoData = data
                    }
                }
            }
        }
    }

    private func save() async {
        isSaving = true
        await careStore.logVisit(note: note, photoData: photoData)
        isSaving = false
        Haptics.success()
        dismiss()
    }
}
