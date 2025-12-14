import SceneKit
import SwiftUI

struct MoleView: View {
  @Binding var state: AppState

  @State private var dragVelocity = CGSize.zero

  // We hold a SceneKit scene instance to manipulate it directly if needed, or let the Representable handle it.
  // To enable "Drag to Spin", we pass gesture data to the representable.

  var body: some View {
    ZStack {
      // Background Atmosphere (2D Glow remains for performance/look)
      Circle()
        .fill(
          RadialGradient(
            gradient: Gradient(colors: [
              Color(hue: 0.6, saturation: 0.8, brightness: 0.6).opacity(0.3),
              Color.purple.opacity(0.1),
              .clear,
            ]),
            center: .center,
            startRadius: 80,
            endRadius: 180
          )
        )
        .frame(width: 300, height: 300)
        .blur(radius: 20)

      // The 3D Scene
      MoleSceneView(state: $state, rotationVelocity: $dragVelocity)
        .frame(width: 320, height: 320) // Slightly larger frame
        .mask(Circle()) // Clip to circle to be safe
        .contentShape(Circle()) // Ensure interaction only happens on the circle
        .onHover { inside in
            if inside {
                NSCursor.openHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .gesture(
          DragGesture()
            .onChanged { gesture in
              // Pass simplified velocity/delta for the Scene to rotate
              dragVelocity = CGSize(width: gesture.translation.width, height: gesture.translation.height)
              NSCursor.closedHand.push() // Grabbing effect
            }
            .onEnded { _ in
              dragVelocity = .zero // Resume auto-spin (handled in view)
              NSCursor.pop() // Release grab
            }
        )

      // UI Overlay: Scanning Ring (2D is sharper for UI elements)
      if state == .scanning || state == .cleaning {
        Circle()
          .trim(from: 0.0, to: 0.75)
          .stroke(
            AngularGradient(
              gradient: Gradient(colors: [.white, .cyan, .clear]),
              center: .center
            ),
            style: StrokeStyle(lineWidth: 3, lineCap: .round)
          )
          .frame(width: 290, height: 290)
          .rotationEffect(.degrees(Double(Date().timeIntervalSince1970) * 360))  // Simple spin
      }
    }
    .scaleEffect(state == .cleaning ? 0.95 : 1.0)
    .animation(.spring, value: state)
  }
}
