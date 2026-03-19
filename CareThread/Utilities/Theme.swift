import SwiftUI

// MARK: - Theme
// ─────────────────────────────────────────────────────────────────────
// Translates your React T(dark) theme function to SwiftUI.
//
// In React, you built a theme object with hex color strings and applied
// them inline via `style={{}}`. SwiftUI handles this differently:
//
// 1. SwiftUI has built-in semantic colors (Color.primary, .secondary)
//    that automatically adapt to light/dark mode — no manual switching!
//
// 2. For custom colors, we define them here and SwiftUI's Environment
//    handles the light/dark toggling automatically.
//
// Think of SwiftUI's @Environment(\.colorScheme) as React's
// useMediaQuery('(prefers-color-scheme: dark)') — but built into the
// framework instead of being a manual hook.
// ─────────────────────────────────────────────────────────────────────

enum AppTheme {
    // MARK: - Brand Colors (match your React accent palette)
    static let accent = Color.blue  // Maps to your #2563eb / #60a5fa
    static let accentSoft = Color.blue.opacity(0.15)

    // MARK: - Status Colors (same across light/dark)
    static let green = Color(red: 0.133, green: 0.773, blue: 0.369)   // #22c55e
    static let yellow = Color(red: 0.918, green: 0.702, blue: 0.031)  // #eab308
    static let red = Color(red: 0.937, green: 0.267, blue: 0.267)     // #ef4444

    /// Get the Color for a StatusRating — used by StatusDot and StatusLabel.
    /// In React: this was inline in the StatusDot component as a switch on rating.
    static func color(for rating: StatusRating) -> Color {
        switch rating {
        case .green: return green
        case .yellow: return yellow
        case .red: return red
        case .none: return .gray.opacity(0.3)
        }
    }

    // MARK: - Semantic Colors
    // These use SwiftUI's adaptive colors that automatically handle dark mode.
    // No need for the T(dark) pattern from React!

    /// Card background — slightly elevated from the main background
    static let cardBackground = Color(.secondarySystemBackground)

    /// Input field background
    static let inputBackground = Color(.tertiarySystemBackground)

    /// Subtle border color
    static let border = Color(.separator)

    /// Muted text (like your textMuted in React)
    static let textMuted = Color(.tertiaryLabel)

    /// Soft text (like your textSoft in React)
    static let textSoft = Color(.secondaryLabel)
}

// MARK: - View Modifiers
// ─────────────────────────────────────────────────────────────────────
// SwiftUI's version of reusable styled components.
//
// In React, your <Btn> component was a styled wrapper around <button>.
// In SwiftUI, we use ViewModifiers — they're composable decorators
// (like the Decorator pattern in Java) that you chain with .modifier().
//
// Even better, we can define them as extensions on View so they read
// like natural SwiftUI modifiers: .cardStyle() instead of
// .modifier(CardStyle())
// ─────────────────────────────────────────────────────────────────────

/// Reusable card styling — matches your React bgCard + shadow pattern
struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

/// Active/selected tab button style
struct ActiveTabStyle: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .font(.subheadline.weight(isActive ? .semibold : .regular))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isActive ? AppTheme.accent : Color.clear)
            .foregroundStyle(isActive ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// Convenience extensions — so you can write .cardStyle() instead of .modifier(CardModifier())
extension View {
    func cardStyle() -> some View {
        modifier(CardModifier())
    }

    func tabButtonStyle(isActive: Bool) -> some View {
        modifier(ActiveTabStyle(isActive: isActive))
    }
}
