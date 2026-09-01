import SwiftUI

struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var isEnabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(FreeDayFont.headline)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .padding(.vertical, 4)
            .foregroundStyle(FreeDayColor.brandOn)
            .background(isEnabled ? FreeDayColor.brand : FreeDayColor.brand.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: FreeDayRadius.button, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!isEnabled)
        .accessibilityAddTraits(.isButton)
    }
}

struct SecondaryButton: View {
    let title: String
    var systemImage: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(FreeDayFont.headline)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .padding(.vertical, 4)
            .foregroundStyle(FreeDayColor.brand)
            .background(FreeDayColor.surface)
            .overlay(
                RoundedRectangle(cornerRadius: FreeDayRadius.button, style: .continuous)
                    .stroke(FreeDayColor.hairline, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: FreeDayRadius.button, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
    }
}
