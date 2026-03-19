//
//  StatusDot.swift
//  CareThread
//
//  Created by Gian Ramirez on 3/18/26.
//

import SwiftUI

// MARK: - StatusDot
// Maps to your React StatusDot({ rating, size, t }) component.

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
// Maps to your React StatusLabel({ rating, t }) component.

struct StatusLabel: View {
    let rating: StatusRating

    var body: some View {
        Text(rating.displayName)
            .font(.caption.weight(.medium))
            .foregroundStyle(AppTheme.color(for: rating))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(AppTheme.color(for: rating).opacity(0.12))
            .clipShape(Capsule())
    }
}

#Preview {
    VStack(spacing: 12) {
        ForEach(StatusRating.allCases, id: \.self) { rating in
            HStack {
                StatusDot(rating: rating)
                StatusLabel(rating: rating)
            }
        }
    }
    .padding()
}
