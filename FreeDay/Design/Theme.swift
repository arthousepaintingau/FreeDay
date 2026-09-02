import SwiftUI

enum FreeDayColor {
    static let canvas = Color(light: Color(red: 0.99, green: 0.985, blue: 0.975), dark: Color(red: 0.07, green: 0.09, blue: 0.09))
    static let surface = Color(light: Color(red: 1.00, green: 1.00, blue: 1.00), dark: Color(red: 0.13, green: 0.16, blue: 0.16))
    static let ink = Color(light: Color(red: 0.10, green: 0.13, blue: 0.13), dark: Color(red: 0.96, green: 0.96, blue: 0.94))
    static let muted = Color(light: Color(red: 0.38, green: 0.42, blue: 0.41), dark: Color(red: 0.74, green: 0.78, blue: 0.76))
    static let brand = Color(light: Color(red: 0.07, green: 0.46, blue: 0.41), dark: Color(red: 0.40, green: 0.84, blue: 0.68))
    static let brandOn = Color(light: .white, dark: Color(red: 0.05, green: 0.09, blue: 0.08))
    static let free = Color(light: Color(red: 0.02, green: 0.64, blue: 0.36), dark: Color(red: 0.28, green: 0.88, blue: 0.52))
    static let freeOn = Color(light: .white, dark: Color(red: 0.04, green: 0.14, blue: 0.08))
    static let booked = Color(light: Color(red: 0.86, green: 0.12, blue: 0.16), dark: Color(red: 1.00, green: 0.36, blue: 0.34))
    static let bookedOn = Color(light: .white, dark: Color(red: 0.18, green: 0.04, blue: 0.04))
    static let tentative = Color(light: Color(red: 0.72, green: 0.42, blue: 0.02), dark: Color(red: 1.00, green: 0.78, blue: 0.28))
    static let buffer = Color(light: Color(red: 0.96, green: 0.58, blue: 0.04), dark: Color(red: 1.00, green: 0.70, blue: 0.22))
    static let hairline = Color(light: Color(red: 0.90, green: 0.89, blue: 0.86), dark: Color(red: 0.26, green: 0.31, blue: 0.30))
    static let lift = Color(light: Color.black.opacity(0.06), dark: Color.black.opacity(0.28))

    static func status(_ availability: DayAvailability) -> Color {
        switch availability {
        case .free: free
        case .booked: booked
        case .tentative: tentative
        case .nonWorking: muted
        }
    }

    static func status(_ kind: CalendarDayKind) -> Color {
        kind == .buffer ? buffer : status(kind.colorAvailability)
    }

    static func statusFill(_ kind: CalendarDayKind) -> Color {
        switch kind {
        case .free: free.opacity(0.14)
        case .booked: booked.opacity(0.16)
        case .buffer: buffer.opacity(0.18)
        case .quoted: tentative.opacity(0.16)
        case .completed: free.opacity(0.08)
        case .nonWorking: Color.clear
        }
    }
}

enum FreeDayFont {
    static let display = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let title = Font.system(.title2, design: .rounded, weight: .semibold)
    static let headline = Font.system(.headline, design: .rounded, weight: .semibold)
    static let body = Font.system(.body, design: .rounded)
    static let caption = Font.system(.subheadline, design: .rounded)
    static let label = Font.system(.caption, design: .rounded, weight: .semibold)
}

enum FreeDayRadius {
    static let card: CGFloat = 24
    static let button: CGFloat = 20
    static let chip: CGFloat = 12
    static let field: CGFloat = 16
}

enum FreeDaySpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let screen: CGFloat = 20
    static let iPadContent: CGFloat = 720
    static let iPadCalendar: CGFloat = 960
    static let touch: CGFloat = 44
}

enum FreeDayTheme {
    static let colors = FreeDayColor.self
    static let fonts = FreeDayFont.self
    static let radius = FreeDayRadius.self
    static let spacing = FreeDaySpacing.self
}

private extension Color {
    init(light: Color, dark: Color) {
        self.init(
            uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
            }
        )
    }
}

struct FreeDayContentWidth: ViewModifier {
    var maxWidth: CGFloat = FreeDaySpacing.iPadContent
    @Environment(\.horizontalSizeClass) private var sizeClass

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: sizeClass == .regular ? maxWidth : .infinity)
            .frame(maxWidth: .infinity)
    }
}

extension View {
    func freeDayContentWidth(_ maxWidth: CGFloat = FreeDaySpacing.iPadContent) -> some View {
        modifier(FreeDayContentWidth(maxWidth: maxWidth))
    }
}
