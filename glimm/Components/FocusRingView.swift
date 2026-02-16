import SwiftUI

struct FocusRingView: View {
    let position: CGPoint
    
    @State private var scale: CGFloat = 1.2

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .strokeBorder(Color.yellow, lineWidth: 1.5)
            .frame(width: 70, height: 70)
            .scaleEffect(scale)
            .position(position)
            .onAppear {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    scale = 1.0
                }
            }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        FocusRingView(
            position: CGPoint(x: 200, y: 300)
        )
    }
}
