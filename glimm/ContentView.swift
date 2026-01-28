//
//  ContentView.swift
//  glimm
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        MainTabView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Memory.self, Settings.self], inMemory: true)
}
