import SwiftUI

// MARK: - StatusDot
// ─────────────────────────────────────────────────────────────────────
// Direct translation of your React <StatusDot> component.
//
// In React: function StatusDot({ rating, size, t }) { ... }
// In SwiftUI: struct StatusDot: View { ... }
//
// KEY CONCEPT — SwiftUI Views are structs, not classes:
// In React, components re-render when state/props change.
// In SwiftUI, the struct is recreated (it's cheap — value type on the stack)
// and SwiftUI diffs the output, just like React's virtual DOM.
//
// Think of `var body: some View` as your render() method in React.
// ─────────────────────────────────────────────────────────────────────

struct StatusDot: View {
    let rating: StatusRating
    var size: CGFloat = 10

    var body: some View {
        Circle()
            .fill(AppTheme.color(for: rating))
            .frame(width: size, height: size)
    }
}

// MARK: - StatusLabel
// ─────────────────────────────────────────────────────────────────────
// Your React <StatusLabel> — shows "Normal", "Off routine", "Flagged"
// with a colored background pill.
// ─────────────────────────────────────────────────────────────────────

struct StatusLabel: View {
    let rating: StatusRating

    var body: some View {
        Text(rating.label)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(AppTheme.color(for: rating).opacity(0.15))
            .foregroundStyle(AppTheme.color(for: rating))
            .clipShape(Capsule())
    }
}

// MARK: - Preview
// ─────────────────────────────────────────────────────────────────────
// #Preview is Xcode's live preview — like Storybook for React.
// You see the component rendered in real time as you edit the code.
// ─────────────────────────────────────────────────────────────────────

#Preview("Status Dots") {
    HStack(spacing: 12) {
        ForEach(StatusRating.allCases, id: \.self) { rating in
            VStack {
                StatusDot(rating: rating)
                StatusLabel(rating: rating)
            }
        }
    }
    .padding()
}
