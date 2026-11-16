import SwiftUI

/// Design tokens for the whole app, in one place (dark theme only for now).
/// The values come from section 9 of docs/BRIEF.md. Use these instead of
/// writing colours, radii or fonts directly in a view.
enum Theme {

    enum Palette {
        static let background = Color(hex: 0x141210)
        static let surface = Color(hex: 0x1E1B18)
        static let border = Color(hex: 0x2E2925)
        static let borderStrong = Color(hex: 0x6E655B)
        static let text = Color(hex: 0xEFE8DC)
        static let textSecondary = Color(hex: 0xABA195)
        static let accent = Color(hex: 0xE5573B)
        /// Text and icons placed on top of the accent colour.
        static let onAccent = Color(hex: 0x141210)
        static let warning = Color(hex: 0xE8A33D)
        /// Stretch map: skin that is stretched under the design.
        static let stretched = Color(hex: 0xF28C38)
        /// Stretch map: skin that is squeezed under the design.
        static let squeezed = Color(hex: 0x4F8BE8)
    }

    enum Radius {
        static let button: CGFloat = 14
        static let card: CGFloat = 20
    }

    enum Size {
        /// Smallest allowed width and height for anything tappable.
        static let minTouchTarget: CGFloat = 44
    }

    /// Fonts. Phase 0 uses system fonts as stand-ins; Phase 1 bundles
    /// Anton, DM Sans and JetBrains Mono and swaps them in here, in one place.
    enum Typography {
        /// Display text (Anton, uppercase). Apply `.textCase(.uppercase)` at the call site.
        static func display(_ size: CGFloat) -> Font {
            .system(size: size, weight: .heavy, design: .default)
        }

        /// Interface text (DM Sans).
        static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight, design: .default)
        }

        /// All measurements and numbers (JetBrains Mono).
        static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            .system(size: size, weight: weight, design: .monospaced)
        }
    }
}

extension Color {
    /// Creates a colour from a hex number such as `0xE5573B`.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
