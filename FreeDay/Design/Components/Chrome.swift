import SwiftUI
import UIKit

struct FreeDaySectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(FreeDayFont.label)
            .foregroundStyle(FreeDayColor.muted)
            .textCase(.uppercase)
            .tracking(0.8)
    }
}

struct FreeDayEmptyState: View {
    let title: String
    var message: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: FreeDaySpacing.xs) {
            Text(title)
                .font(FreeDayFont.title)
                .foregroundStyle(FreeDayColor.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let message {
                Text(message)
                    .font(FreeDayFont.body)
                    .foregroundStyle(FreeDayColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct PersonalityLine: View {
    let text: String
    var style: Style = .title

    enum Style {
        case title
        case caption
    }

    var body: some View {
        Text(text)
            .font(style == .title ? FreeDayFont.title : FreeDayFont.caption)
            .foregroundStyle(style == .title ? FreeDayColor.ink : FreeDayColor.muted)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.updatesFrequently)
    }
}

struct PressableButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.98

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? pressedScale : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(Motion.animation(reduceMotion, .snappy(duration: 0.16)), value: configuration.isPressed)
    }
}

struct FreeDayField: View {
    let title: String
    var hint: String? = nil
    var isRequired: Bool = false
    @Binding var text: String
    var axis: Axis = .horizontal
    var keyboardType: UIKeyboardType = .default
    var textContentType: UITextContentType? = nil
    var submitLabel: SubmitLabel = .next

    var body: some View {
        VStack(alignment: .leading, spacing: FreeDaySpacing.xs) {
            HStack(spacing: FreeDaySpacing.xs) {
                FreeDaySectionHeader(title: title)
                if isRequired {
                    Text(String(localized: "Required", comment: "Required field marker"))
                        .font(FreeDayFont.label)
                        .foregroundStyle(FreeDayColor.muted)
                }
            }
            TextField(hint ?? title, text: $text, axis: axis)
                .font(FreeDayFont.body)
                .foregroundStyle(FreeDayColor.ink)
                .keyboardType(keyboardType)
                .textContentType(textContentType)
                .submitLabel(submitLabel)
                .padding(FreeDaySpacing.md)
                .frame(minHeight: FreeDaySpacing.touch)
                .background(FreeDayColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: FreeDayRadius.field, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: FreeDayRadius.field, style: .continuous)
                        .stroke(FreeDayColor.hairline, lineWidth: 1)
                )
        }
    }
}

struct FreeDayLabeledValue: View {
    let title: String
    let value: String
    var prominent: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            FreeDaySectionHeader(title: title)
            Text(value)
                .font(prominent ? FreeDayFont.title : FreeDayFont.body)
                .foregroundStyle(FreeDayColor.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
