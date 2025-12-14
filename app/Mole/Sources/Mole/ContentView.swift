import SwiftUI

struct ContentView: View {
  @State private var appState: AppState = .idle
  @State private var logs: [String] = []

  // Connect to Real Logic
  @StateObject private var scanner = ScannerService()

  // The requested coffee/dark brown color
  let deepBrown = Color(red: 0.17, green: 0.11, blue: 0.05)  // #2C1C0E

  var body: some View {
    ZStack {
      // Background
      Color.black.ignoresSafeArea()

      // Ambient Gradient
      RadialGradient(
        gradient: Gradient(colors: [deepBrown, .black]),
        center: .center,
        startRadius: 0,
        endRadius: 600
      )
      .ignoresSafeArea()

      VStack(spacing: -10) {
        Spacer()

        // The Mole (Interactive)
        MoleView(state: $appState)
          .onTapGesture {
            handleMoleInteraction()
          }

        // Status Area
        ZStack {
          // Logs overlay (visible during scanning/cleaning)
          if case .scanning = appState {
            LogView(logs: logs)
              .transition(.opacity)
          } else if case .cleaning = appState {
            LogView(logs: logs)
              .transition(.opacity)
          } else {
            // Standard Status Text
            VStack(spacing: 24) {
              statusText

              if case .idle = appState {
                // Premium Button Style
                Button(action: {
                  startScanning()
                }) {
                  Text("CHECK")
                    .font(.system(size: 14, weight: .bold, design: .monospaced)) // Tech Font
                    .tracking(4)
                    .foregroundStyle(.white)
                    .frame(maxWidth: 160)
                    .padding(.vertical, 14)
                    .background(
                      Capsule()
                        .fill(Color(red: 0.8, green: 0.25, blue: 0.1).opacity(0.9))
                    )
                    .overlay(
                      Capsule()
                        .strokeBorder(Color.white.opacity(0.5), lineWidth: 1.5) // Sharper Border
                    )
                    .shadow(color: Color(red: 0.8, green: 0.25, blue: 0.1).opacity(0.5), radius: 10, x: 0, y: 0) // Glow
                }
                .buttonStyle(.plain)
                .onHover { inside in
                    inside ? NSCursor.pointingHand.push() : NSCursor.pop()
                }
              } else if case .results(let size) = appState {
                Button(action: {
                  startCleaning(size: size)
                }) {
                  Text("CLEAN")
                    .font(.system(size: 14, weight: .bold, design: .monospaced)) // Tech Font
                    .tracking(4)
                    .foregroundStyle(.white)
                    .frame(maxWidth: 160)
                    .padding(.vertical, 14)
                    .background(
                      Capsule()
                        .fill(.white.opacity(0.1))
                    )
                    .overlay(
                      Capsule()
                        .strokeBorder(Color.white.opacity(0.5), lineWidth: 1.5) // Sharper Border
                    )
                    .shadow(color: .white.opacity(0.2), radius: 10, x: 0, y: 0)
                }
                .buttonStyle(.plain)
                .onHover { inside in
                   inside ? NSCursor.pointingHand.push() : NSCursor.pop()
               }
              }
            }
            .transition(.opacity)
          }
        }
        .frame(height: 100)

        Spacer()
      }
    }
    .frame(minWidth: 600, minHeight: 500)
    .onChange(of: scanner.currentLog) {
      // Stream logs from scanner to local state
      if !scanner.currentLog.isEmpty {
        withAnimation(.spring) {
          logs.append(scanner.currentLog)
        }
      }
    }
  }

  var statusText: some View {
    VStack(spacing: 8) {
      Text(mainStatusTitle)
        .font(.system(size: 32, weight: .bold, design: .rounded))
        .foregroundStyle(.white)
    }
  }

  var mainStatusTitle: String {
    switch appState {
    case .idle: return "Ready"
    case .scanning: return "Scanning..."
    case .results(let size): return "\(size)"
    case .cleaning: return "Cleaning..."
    case .done: return "Done"
    }
  }

  var subStatusTitle: String {
    switch appState {
    case .idle: return "System ready."
    case .scanning: return ""
    case .results: return "Caches • Logs • Debris"
    case .cleaning: return ""
    case .done: return "System is fresh"
    }
  }

  func handleMoleInteraction() {
    if case .idle = appState {
      startScanning()
    } else if case .done = appState {
      withAnimation {
        appState = .idle
        logs.removeAll()
      }
    }
  }

  func startScanning() {
    withAnimation {
      appState = .scanning
      logs.removeAll()
    }

    // Trigger Async Scan
    Task {
      await scanner.startScan()

      let sizeMB = Double(scanner.totalSize) / 1024.0 / 1024.0
      let sizeString =
        sizeMB > 1024 ? String(format: "%.1f GB", sizeMB / 1024) : String(format: "%.0f MB", sizeMB)

      withAnimation {
        appState = .results(size: sizeString)
      }
    }
  }

  func startCleaning(size: String) {
    withAnimation {
      appState = .cleaning
      logs.removeAll()
    }

    Task {
      await scanner.clean()

      withAnimation {
        appState = .done
      }
    }
  }
}
