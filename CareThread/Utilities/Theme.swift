//
//  Theme.swift
//  CareThread
//
//  Created by Gian Ramirez on 3/18/26.
//

import SwiftUI

enum AppTheme {
    static let accent = Color.blue
    static let accentSoft = Color.blue.opacity(0.15)

    static let green = Color(red: 0.133, green: 0.773, blue: 0.369)
    static let yellow = Color(red: 0.918, green: 0.702, blue: 0.031)
    static let red = Color(red: 0.937, green: 0.267, blue: 0.267)

    static func color(for rating: StatusRating) -> Color {
        switch rating {
        case .green: return green
        case .yellow: return yellow
        case .red: return red
        case .none: return .gray.opacity(0.3)
        }
    }

    static let cardBackground = Color(.secondarySystemBackground)
    static let inputBackground = Color(.tertiarySystemBackground)
    static let border = Color(.separator)
    static let textMuted = Color(.tertiaryLabel)
    static let textSoft = Color(.secondaryLabel)
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

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

extension View {
    func cardStyle() -> some View {
        modifier(CardModifier())
    }

    func tabButtonStyle(isActive: Bool) -> some View {
        modifier(ActiveTabStyle(isActive: isActive))
    }
}
