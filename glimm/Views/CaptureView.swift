//
//  CaptureView.swift
//  glimm
//

import SwiftUI
import SwiftData
import AVFoundation
import Combine

struct CaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = CameraModel()
    @State private var capturedImage: UIImage?
    @State private var showNoteInput = false
    @State private var note = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let image = capturedImage {
                previewView(image: image)
            } else {
                cameraView
            }
        }
        .sheet(isPresented: $showNoteInput) {
            noteInputSheet
        }
    }

    private var cameraView: some View {
        ZStack {
            CameraPreview(camera: camera)
                .ignoresSafeArea()

            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }

                    Spacer()

                    Button {
                        camera.switchCamera()
                    } label: {
                        Image(systemName: "camera.rotate")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
                .padding()

                Spacer()

                Button {
                    camera.capturePhoto { image in
                        capturedImage = image
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(.white)
                            .frame(width: 72, height: 72)
                        Circle()
                            .stroke(.white, lineWidth: 4)
                            .frame(width: 84, height: 84)
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            camera.checkPermission()
        }
    }

    private func previewView(image: UIImage) -> some View {
        ZStack {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()

            VStack {
                Spacer()

                HStack(spacing: 32) {
                    Button {
                        capturedImage = nil
                    } label: {
                        Text("Retake")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    }

                    Button {
                        showNoteInput = true
                    } label: {
                        Text("Use Photo")
                            .font(.headline)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(.white)
                            .clipShape(Capsule())
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }

    private var noteInputSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
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
                    Button("Skip") {
                        saveMemory(withNote: nil)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveMemory(withNote: note.isEmpty ? nil : note)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func saveMemory(withNote note: String?) {
        guard let image = capturedImage,
              let imageData = image.jpegData(compressionQuality: 0.8) else {
            return
        }

        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let memory = Memory(
            imageData: imageData,
            note: trimmedNote?.isEmpty == false ? trimmedNote : nil
        )
        modelContext.insert(memory)

        showNoteInput = false
        dismiss()
    }
}

// MARK: - Camera Model

class CameraModel: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var output = AVCapturePhotoOutput()
    @Published var preview: AVCaptureVideoPreviewLayer?
    @Published var isTaken = false
    @Published var position: AVCaptureDevice.Position = .back

    private var photoCompletion: ((UIImage?) -> Void)?

    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setUp()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async {
                        self.setUp()
                    }
                }
            }
        default:
            break
        }
    }

    func setUp() {
        do {
            session.beginConfiguration()
            session.sessionPreset = .photo

            guard let device = AVCaptureDevice.default(
                .builtInWideAngleCamera,
                for: .video,
                position: position
            ) else { return }

            let input = try AVCaptureDeviceInput(device: device)

            if session.canAddInput(input) {
                session.addInput(input)
            }

            if session.canAddOutput(output) {
                session.addOutput(output)
            }

            session.commitConfiguration()

            DispatchQueue.global(qos: .userInitiated).async {
                self.session.startRunning()
            }
        } catch {
            print("Camera setup error: \(error)")
        }
    }

    func switchCamera() {
        session.beginConfiguration()

        guard let currentInput = session.inputs.first as? AVCaptureDeviceInput else {
            return
        }

        session.removeInput(currentInput)

        position = position == .back ? .front : .back

        guard let newDevice = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: position
        ) else { return }

        do {
            let newInput = try AVCaptureDeviceInput(device: newDevice)
            if session.canAddInput(newInput) {
                session.addInput(newInput)
            }
        } catch {
            print("Switch camera error: \(error)")
        }

        session.commitConfiguration()
    }

    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        photoCompletion = completion
        let settings = AVCapturePhotoSettings()
        output.capturePhoto(with: settings, delegate: self)
    }
}

extension CameraModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil,
              let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            photoCompletion?(nil)
            return
        }

        DispatchQueue.main.async {
            self.photoCompletion?(image)
        }
    }
}

// MARK: - Camera Preview

struct CameraPreview: UIViewRepresentable {
    @ObservedObject var camera: CameraModel

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black

        let previewLayer = AVCaptureVideoPreviewLayer(session: camera.session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        camera.preview = previewLayer

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        camera.preview?.frame = uiView.bounds
    }
}

#Preview {
    CaptureView()
        .modelContainer(for: Memory.self, inMemory: true)
}
