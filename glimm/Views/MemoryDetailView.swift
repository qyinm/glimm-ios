//
//  MemoryDetailView.swift
//  glimm
//

import SwiftUI
import SwiftData

struct MemoryDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let memory: Memory

    @State private var showEditNote = false
    @State private var editedNote: String = ""
    @State private var showDeleteConfirmation = false
    @State private var showShareSheet = false
    @State private var showLocationPicker = false
    @State private var editedLocationName: String?
    @State private var editedLatitude: Double?
    @State private var editedLongitude: Double?

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    Color.black.ignoresSafeArea()

                    if let imageData = memory.imageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    }

                    VStack {
                        Spacer()

                        infoOverlay
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showShareSheet = true
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }

                        Button {
                            editedNote = memory.note ?? ""
                            showEditNote = true
                        } label: {
                            Label("Edit Note", systemImage: "pencil")
                        }

                        Button {
                            editedLocationName = memory.locationName
                            editedLatitude = memory.latitude
                            editedLongitude = memory.longitude
                            showLocationPicker = true
                        } label: {
                            Label("Edit Location", systemImage: "location")
                        }

                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
            }
            .sheet(isPresented: $showEditNote) {
                editNoteSheet
            }
            .confirmationDialog(
                "Delete Memory",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    deleteMemory()
                }
            } message: {
                Text("This cannot be undone.")
            }
            .sheet(isPresented: $showShareSheet) {
                if let imageData = memory.imageData,
                   let uiImage = UIImage(data: imageData) {
                    ShareSheet(items: [uiImage])
                }
            }
            .sheet(isPresented: $showLocationPicker, onDismiss: saveLocation) {
                LocationPickerView(
                    selectedLocationName: $editedLocationName,
                    selectedLatitude: $editedLatitude,
                    selectedLongitude: $editedLongitude
                )
            }
        }
    }

    private func saveLocation() {
        memory.locationName = editedLocationName
        memory.latitude = editedLatitude
        memory.longitude = editedLongitude
    }

    private var infoOverlay: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let note = memory.note, !note.isEmpty {
                Text(note)
                    .font(.body)
                    .foregroundStyle(.white)
            }

            HStack {
                Text(memory.capturedAt, format: .dateTime.month().day().year())
                Text("at")
                Text(memory.capturedAt, format: .dateTime.hour().minute())
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.7))

            if let locationName = memory.locationName {
                Button {
                    openInMaps()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                        Text(locationName)
                    }
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private func openInMaps() {
        guard let lat = memory.latitude, let lon = memory.longitude else { return }
        if let url = URL(string: "maps://?ll=\(lat),\(lon)") {
            UIApplication.shared.open(url)
        }
    }

    private var editNoteSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Edit note")
                    .font(.title2)
                    .fontWeight(.semibold)

                TextField("What's happening?", text: $editedNote, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(16)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .lineLimit(3...6)

                Text("\(editedNote.count)/280")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                Spacer()
            }
            .padding(24)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        showEditNote = false
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveNote()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func saveNote() {
        let trimmed = editedNote.trimmingCharacters(in: .whitespacesAndNewlines)
        memory.note = trimmed.isEmpty ? nil : trimmed
        showEditNote = false
    }

    private func deleteMemory() {
        modelContext.delete(memory)
        dismiss()
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    let memory = Memory(
        imageData: nil,
        note: "Coffee with an old friend",
        capturedAt: .now
    )

    return MemoryDetailView(memory: memory)
        .modelContainer(for: Memory.self, inMemory: true)
}
