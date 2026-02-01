//
//  CaptureView.swift
//  glimm
//

import SwiftUI
import SwiftData
import PhotosUI
import CoreLocation

struct CaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationService = LocationService()
    @State private var capturedImage: UIImage?
    @State private var showNoteInput = false
    @State private var note = ""
    @State private var showLocationPicker = false
    @State private var selectedLocationName: String?
    @State private var selectedLatitude: Double?
    @State private var selectedLongitude: Double?

    var body: some View {
        ImagePicker(image: $capturedImage, sourceType: .camera, onCancel: {
            dismiss()
        })
        .ignoresSafeArea()
        .sheet(isPresented: $showNoteInput) {
            noteInputSheet
        }
        .onChange(of: capturedImage) { _, newValue in
            if newValue != nil {
                showNoteInput = true
            }
        }
        .onAppear {
            locationService.requestLocation()
        }
    }

    private var noteInputSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let image = capturedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                Text("Add a note")
                    .font(.title2)
                    .fontWeight(.semibold)

                TextField("What's happening right now?", text: $note, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(16)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .lineLimit(3...6)
                    .onChange(of: note) { _, newValue in
                        if newValue.count > 280 {
                            note = String(newValue.prefix(280))
                        }
                    }

                Text("\(note.count)/280")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                // Location picker button
                Button {
                    showLocationPicker = true
                } label: {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundStyle(.blue)
                        if let locationName = selectedLocationName {
                            Text(locationName)
                                .foregroundStyle(.primary)
                        } else {
                            Text("Add Location")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Spacer()
            }
            .padding(24)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        showNoteInput = false
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveMemory()
                    }
                    .fontWeight(.semibold)
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
              let imageData = image.jpegData(compressionQuality: 0.8) else {
            return
        }

        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        let memory = Memory(
            imageData: imageData,
            note: trimmedNote.isEmpty ? nil : trimmedNote,
            latitude: selectedLatitude,
            longitude: selectedLongitude,
            locationName: selectedLocationName
        )
        modelContext.insert(memory)

        showNoteInput = false
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
