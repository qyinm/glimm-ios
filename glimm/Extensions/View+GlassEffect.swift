//
//  View+GlassEffect.swift
//  glimm
//

import SwiftUI

extension View {
    /// Applies a glass effect (ultra thin material) with rounded corners
    /// - Parameter cornerRadius: The corner radius for the clip shape. Default is 12.
    /// - Returns: A view with glass effect applied
    func glassEffect(cornerRadius: CGFloat = 12) -> some View {
        self
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    /// Applies a glass card effect with larger corner radius
    /// - Returns: A view with card-style glass effect (24pt corners)
    func glassCard() -> some View {
        self.glassEffect(cornerRadius: 24)
    }
}
