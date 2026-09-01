import SwiftUI

struct ToastBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .font(FreeDayFont.headline)
            .foregroundStyle(FreeDayColor.ink)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(FreeDayColor.surface)
            .overlay(
                Capsule()
                    .stroke(FreeDayColor.hairline, lineWidth: 1)
            )
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
            .accessibilityAddTraits(.updatesFrequently)
    }
}
