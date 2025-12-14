import SwiftUI

@main
struct MoleApp: App {
  var body: some Scene {
    WindowGroup("Mole") {
      ContentView()
    }
    .windowStyle(.hiddenTitleBar)
    .windowResizability(.contentSize)
  }
}
