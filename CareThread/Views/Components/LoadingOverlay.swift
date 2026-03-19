//
//  LoadingOverlay.swift
//  CareThread
//
//  Created by Gian Ramirez on 3/18/26.
//

import SwiftUI

// MARK: - LoadingOverlay
// Shown over the entire app when Claude API is processing.

struct LoadingOverlay: View {
    let message: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                Text(message.isEmpty ? "Processing..." : message)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: true)
    }
}

// MARK: - Toast Modifier
// Maps to your React toast notification system.

struct ToastModifier: ViewModifier {
    @Binding var message: String?
    var isError: Bool = false

    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content

            if let msg = message {
                Text(msg)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(isError ? AppTheme.red : AppTheme.green)
                    .clipShape(Capsule())
                    .shadow(radius: 8)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        Task {
                            try? await Task.sleep(for: .seconds(2.5))
                            withAnimation { message = nil }
                        }
                    }
            }
        }
        .animation(.spring(response: 0.3), value: message)
    }
}

extension View {
    func toast(message: Binding<String?>, isError: Bool = false) -> some View {
        modifier(ToastModifier(message: message, isError: isError))
    }
}
