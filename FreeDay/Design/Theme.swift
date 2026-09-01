import SwiftUI

enum FreeDayColor {
    static let canvas = Color(light: Color(red: 0.96, green: 0.94, blue: 0.90), dark: Color(red: 0.08, green: 0.11, blue: 0.10))
    static let surface = Color(light: Color(red: 1.00, green: 0.99, blue: 0.97), dark: Color(red: 0.14, green: 0.18, blue: 0.17))
    static let ink = Color(light: Color(red: 0.12, green: 0.16, blue: 0.15), dark: Color(red: 0.95, green: 0.95, blue: 0.93))
    static let muted = Color(light: Color(red: 0.42, green: 0.46, blue: 0.44), dark: Color(red: 0.72, green: 0.76, blue: 0.74))
    static let brand = Color(light: Color(red: 0.09, green: 0.48, blue: 0.42), dark: Color(red: 0.38, green: 0.82, blue: 0.66))
    static let brandOn = Color(light: .white, dark: Color(red: 0.06, green: 0.10, blue: 0.09))
    static let free = Color(light: Color(red: 0.13, green: 0.62, blue: 0.38), dark: Color(red: 0.42, green: 0.86, blue: 0.58))
    static let booked = Color(light: Color(red: 0.82, green: 0.24, blue: 0.24), dark: Color(red: 0.96, green: 0.48, blue: 0.46))
    static let tentative = Color(light: Color(red: 0.85, green: 0.58, blue: 0.05), dark: Color(red: 0.99, green: 0.80, blue: 0.28))
    static let buffer = Color(light: Color(red: 0.89, green: 0.45, blue: 0.16), dark: Color(red: 1.00, green: 0.68, blue: 0.38))
    static let hairline = Color(light: Color(red: 0.88, green: 0.85, blue: 0.80), dark: Color(red: 0.28, green: 0.33, blue: 0.31))

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
