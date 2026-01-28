//
//  CaptureView.swift
//  glimm
//

import SwiftUI
import SwiftData
import PhotosUI

struct CaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var capturedImage: UIImage?
    @State private var showCamera = true
    @State private var showNoteInput = false
    @State private var note = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let image = capturedImage {
                previewView(image: image)
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            ImagePicker(image: $capturedImage, sourceType: .camera)
                .ignoresSafeArea()
                .onDisappear {
                    if capturedImage == nil {
                        dismiss()
                    }
                }
        }
        .sheet(isPresented: $showNoteInput) {
            noteInputSheet
        }
        .onChange(of: capturedImage) { _, newValue in
            if newValue != nil {
                showNoteInput = true
            }
        }
    }

    private func previewView(image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .ignoresSafeArea()
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

                Text("\(note.count)/280")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                Spacer()
            }
            .padding(24)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Retake") {
                        showNoteInput = false
                        capturedImage = nil
                        showCamera = true
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveMemory()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .interactiveDismissDisabled()
        .presentationDetents([.large])
    }

    private func saveMemory() {
        guard let image = capturedImage,
              let imageData = image.jpegData(compressionQuality: 0.8) else {
            return
        }

        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let memory = Memory(
            imageData: imageData,
            note: trimmedNote.isEmpty ? nil : trimmedNote
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
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

#Preview {
    CaptureView()
        .modelContainer(for: Memory.self, inMemory: true)
}
