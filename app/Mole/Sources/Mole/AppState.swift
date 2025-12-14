import SwiftUI

enum AppState: Equatable {
    case idle
    case scanning
    case results(size: String)
    case cleaning
    case done
}
