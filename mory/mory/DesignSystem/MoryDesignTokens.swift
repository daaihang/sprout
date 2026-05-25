import SwiftUI

// MARK: - Spacing

enum MorySpacing {
    static let xSmall: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let xLarge: CGFloat = 24
}

// MARK: - Corner Radius

/// Standard corner radii used across the app.
/// Prefer these over inline magic numbers for visual consistency.
enum MoryCornerRadius {
    /// Smallest rounding for inline elements like tags or bars (6pt).
    static let small: CGFloat = 6
    /// Standard rounding for cards and thumbnails (8pt).
    static let medium: CGFloat = 8
    /// Moderate rounding for interactive elements like buttons and inputs (12pt).
    static let large: CGFloat = 12
    /// Large rounding for hero cards and map clips (18–20pt).
    static let xLarge: CGFloat = 20
}

// MARK: - Semantic Colors

/// Semantic color tokens. Values resolve to system dynamic colors so they
/// automatically adapt to light / dark mode and accessibility settings.
/// Add explicit `Color(...)` overrides here when the brand diverges from
/// the system palette.
enum MoryColors {
    // MARK: Content hierarchy (maps to system semantic colors)
    static let primary: Color = .primary
    static let secondary: Color = .secondary
    static let tertiary: Color = Color(uiColor: .tertiaryLabel)

    // MARK: Accent & interaction
    static let accent: Color = .accentColor
    static let destructive: Color = .red

    // MARK: Surfaces
    static let background: Color = Color(uiColor: .systemBackground)
    static let secondaryBackground: Color = Color(uiColor: .secondarySystemBackground)
    static let groupedBackground: Color = Color(uiColor: .systemGroupedBackground)

    // MARK: Capture card palette
    static let cardSurface: Color = Color(uiColor: .secondarySystemGroupedBackground)
}

// MARK: - Typography

/// Predefined text styles that pair a system design with a semantic weight.
/// Use these for non-standard combinations; for standard `.headline`, `.body`
/// etc., SwiftUI's built-in `Font` text styles are preferred.
enum MoryTypography {
    static let cardTitle: Font = .subheadline.weight(.semibold)
    static let cardCaption: Font = .caption
    static let sectionHeader: Font = .headline
    static let metadataLabel: Font = .footnote
}

// MARK: - Shadows

enum MoryShadow {
    /// Subtle card shadow.
    static let card = ShadowStyle(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
    /// Elevated element shadow (e.g. floating action button).
    static let elevated = ShadowStyle(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
}

struct ShadowStyle: Sendable {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - Animation

enum MoryAnimation {
    /// Standard spring for interactive transitions.
    static let defaultSpring: Animation = .spring(response: 0.35, dampingFraction: 0.85)
    /// Quick response for small state changes.
    static let quick: Animation = .easeInOut(duration: 0.2)
}
