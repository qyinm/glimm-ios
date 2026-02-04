//
//  NoteTextField.swift
//  glimm
//

import SwiftUI

struct NoteTextField: View {
    @Binding var text: String
    let placeholder: String
    private let characterLimit = 280

    var body: some View {
        VStack(spacing: 8) {
            TextField(placeholder, text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(16)
                .glassEffect(cornerRadius: 12)
                .lineLimit(3...6)
                .onChange(of: text) { _, newValue in
                    if newValue.count > characterLimit {
                        text = String(newValue.prefix(characterLimit))
                    }
                }

            Text("\(text.count)/\(characterLimit)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

#Preview {
    @Previewable @State var note = ""

    return VStack {
        NoteTextField(text: $note, placeholder: "Add a note...")
            .padding()
    }
}
