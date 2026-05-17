//
//  CaptureView.swift
//  glimm
//

import SwiftUI
import SwiftData
import CoreLocation

struct CaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationService = LocationService()
    @State private var capturedImage: UIImage?
    @State private var showCaptureReview = false
    @State private var showNoteEditor = false
    @State private var showAudioEditor = false
    @State private var note = ""
    @State private var audioData: Data?
    @State private var audioDuration: Double?
    @State private var isAudioRecording = false
    @State private var showLocationPicker = false
    @State private var selectedLocationName: String?
    @State private var selectedLatitude: Double?
    @State private var selectedLongitude: Double?

    var body: some View {
        DualCaptureView(
            onImageCaptured: { image in
                capturedImage = image
            },
            onCancel: {
                dismiss()
            }
        )
        .sheet(isPresented: $showCaptureReview) {
            captureReviewSheet
        }
        .onChange(of: capturedImage) { _, newValue in
            if newValue != nil {
                showCaptureReview = true
            }
        }
        .onAppear {
            locationService.requestLocation()
        }
    }

    private var captureReviewSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let image = capturedImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 260)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    }

                    optionalSection(
                        title: String(localized: "capture.note.title"),
                        subtitle: note.isEmpty
                            ? String(localized: "capture.review.note.add")
                            : note,
                        systemImage: "text.alignleft",
                        isExpanded: $showNoteEditor
                    ) {
                        NoteTextField(
                            text: $note,
                            placeholder: String(localized: "capture.note.placeholder")
                        )
                    }

                    optionalSection(
                        title: String(localized: "capture.audio.title"),
                        subtitle: audioData == nil
                            ? String(localized: "capture.review.audio.add")
                            : String(localized: "capture.audio.saved"),
                        systemImage: "waveform",
                        isExpanded: $showAudioEditor
                    ) {
                        AudioNoteComposer(
                            audioData: $audioData,
                            audioDuration: $audioDuration,
                            isRecording: $isAudioRecording
                        )
                    }

                    Button {
                        showLocationPicker = true
                    } label: {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(String(localized: "capture.location.title"))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                                Text(selectedLocationName ?? String(localized: "capture.location.add"))
                                    .font(.caption)
                                    .foregroundStyle(selectedLocationName == nil ? .secondary : .primary)
                                    .lineLimit(2)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(16)
                        .glassEffect(cornerRadius: 16)
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 0)
                }
                .padding(24)
            }
            .navigationTitle(String(localized: "capture.review.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "common.cancel")) {
                        cancelCapture()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "common.save")) {
                        saveMemory()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSaveMemory)
                }
            }
            .sheet(isPresented: $showLocationPicker) {
                LocationPickerView(
                    selectedLocationName: $selectedLocationName,
                    selectedLatitude: $selectedLatitude,
                    selectedLongitude: $selectedLongitude
                )
            }
            .task {
                await autoDetectLocation()
            }
        }
        .interactiveDismissDisabled()
        .presentationDetents([.large])
    }

    private var canSaveMemory: Bool {
        capturedImage != nil && !isAudioRecording
    }

    @ViewBuilder
    private func optionalSection<Content: View>(
        title: String,
        subtitle: String,
        systemImage: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.wrappedValue.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: systemImage)
                        .foregroundStyle(.primary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded.wrappedValue ? 90 : 0))
                }
                .padding(16)
                .glassEffect(cornerRadius: 16)
            }
            .buttonStyle(.plain)

            if isExpanded.wrappedValue {
                content()
            }
        }
    }

    private func cancelCapture() {
        resetDraft()
        showCaptureReview = false
        dismiss()
    }

    private func resetDraft() {
        capturedImage = nil
        note = ""
        audioData = nil
        audioDuration = nil
        isAudioRecording = false
        selectedLocationName = nil
        selectedLatitude = nil
        selectedLongitude = nil
        showNoteEditor = false
        showAudioEditor = false
    }

    private func autoDetectLocation() async {
        // Wait a bit for location to be available
        try? await Task.sleep(for: .milliseconds(500))

        guard let location = locationService.currentLocation else { return }

        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude

        selectedLatitude = lat
        selectedLongitude = lon

        if let name = await locationService.reverseGeocode(latitude: lat, longitude: lon) {
            selectedLocationName = name
        }
    }

    private func saveMemory() {
        guard let image = capturedImage,
              let imageData = image.jpegData(compressionQuality: 0.8),
              !isAudioRecording else {
            return
        }

        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        let memory = Memory(
            imageData: imageData,
            audioData: audioData,
            note: trimmedNote.isEmpty ? nil : trimmedNote,
            audioDuration: audioDuration,
            latitude: selectedLatitude,
            longitude: selectedLongitude,
            locationName: selectedLocationName
        )
        modelContext.insert(memory)

        resetDraft()
        showCaptureReview = false
        dismiss()
    }
}

// MARK: - Image Picker

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let sourceType: UIImagePickerController.SourceType
    var onCancel: (() -> Void)?

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCancel?()
        }
    }
}

#Preview {
    CaptureView()
        .modelContainer(for: Memory.self, inMemory: true)
}
