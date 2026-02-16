import SwiftUI

struct FocusRingView: View {
    let position: CGPoint
    let exposureBias: Float
    let minExposure: Float
    let maxExposure: Float
    let onExposureChange: (Float) -> Void
    
    @State private var scale: CGFloat = 1.2
    @State private var sliderOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    

    var body: some View {
        ZStack {
            // Focus Ring (Yellow Square)
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(Color.yellow, lineWidth: 1.5)
                .frame(width: 70, height: 70)
                .scaleEffect(scale)
            
            // Exposure Control (Sun + Slider)
            HStack(spacing: 8) {
                if isDragging || abs(sliderOffset) > 5 {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 4, height: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.yellow)
                                .frame(width: 4, height: max(0, 50 - sliderOffset))
                                .offset(y: -sliderOffset / 2)
                        )
                }
                
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.yellow)
                    .offset(y: -sliderOffset)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDragging = true
                                let drag = -value.translation.height
                                sliderOffset = max(-50, min(50, drag))
                                
                                let normalized = Float((sliderOffset + 50) / 100)
                                let newBias = minExposure + (maxExposure - minExposure) * normalized
                                onExposureChange(newBias)
                            }
                            .onEnded { _ in
                                isDragging = false
                            }
                    )
            }
            .position(x: 85, y: 35)
        }
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
            position: CGPoint(x: 200, y: 300),
            exposureBias: 0,
            minExposure: -2,
            maxExposure: 2,
            onExposureChange: { val in
                print("Exposure: \(val)")
            }
        )
    }
}
