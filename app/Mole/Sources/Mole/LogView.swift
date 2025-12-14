import SwiftUI

struct LogView: View {
    let logs: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(logs.suffix(5).enumerated()), id: \.offset) { index, log in
                Text(log)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(.white.opacity(opacity(for: index, count: logs.suffix(5).count)))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(height: 100)
        .mask(
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.2),
                    .init(color: .black, location: 0.8),
                    .init(color: .clear, location: 1.0)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    func opacity(for index: Int, count: Int) -> Double {
        // Newer items (higher index) are more opaque
        let normalizedIndex = Double(index) / Double(max(count - 1, 1))
        return 0.3 + (normalizedIndex * 0.7)
    }
}
