import SwiftUI

enum Motion {
    @MainActor
    static func animation(_ reduceMotion: Bool, _ animation: Animation = .snappy(duration: 0.28)) -> Animation? {
        reduceMotion ? nil : animation
    }
}
