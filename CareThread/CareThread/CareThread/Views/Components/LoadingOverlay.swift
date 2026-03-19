import SwiftUI

// MARK: - LoadingOverlay
// ─────────────────────────────────────────────────────────────────────
// Maps to your React loading state: {loading && <div className="overlay">...}
// In SwiftUI, overlays are applied as view modifiers — much cleaner
// than conditional rendering + absolute positioning in CSS.
// ─────────────────────────────────────────────────────────────────────

struct LoadingOverlay: View {
    let message: String

    var body: some View {
        ZStack {
            // Semi-transparent background — like your React overlay div
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                Text(message)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
            }
            .padding(32)
            .background(.ultraThinMaterial)  // Frosted glass effect — native iOS!
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

// MARK: - Toast View
// ─────────────────────────────────────────────────────────────────────
// Maps to your React toast: {toast && <div className="toast">...}
//
// In React you used setTimeout to auto-dismiss.
// In SwiftUI we use .task + Task.sleep for the same effect.
// ─────────────────────────────────────────────────────────────────────

struct ToastView: View {
    let message: String
    let isError: Bool

    var body: some View {
        Text(message)
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(isError ? Color.red.opacity(0.9) : Color.green.opacity(0.9))
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .shadow(radius: 8)
    }
}

// MARK: - Toast Modifier
// ─────────────────────────────────────────────────────────────────────
// A ViewModifier so any view can show a toast with:
//   .toast(message: $toastMessage)
//
// This is a pattern you'll see a lot in SwiftUI — instead of
// managing toast visibility in every component (like your React toast
// state), you create a reusable modifier that handles the animation
// and auto-dismiss logic.
// ─────────────────────────────────────────────────────────────────────

struct ToastModifier: ViewModifier {
    @Binding var message: String?
    var isError: Bool = false
    var duration: TimeInterval = 2.5

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let message {
                    ToastView(message: message, isError: isError)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onAppear {
                            // Auto-dismiss after duration
                            // Task { } launches a concurrent task — like setTimeout in JS
                            Task {
                                try? await Task.sleep(for: .seconds(duration))
                                withAnimation {
                                    self.message = nil
                                }
                            }
                        }
                }
            }
            .animation(.spring(duration: 0.3), value: message)
    }
}

extension View {
    func toast(message: Binding<String?>, isError: Bool = false) -> some View {
        modifier(ToastModifier(message: message, isError: isError))
    }
}

#Preview("Loading") {
    LoadingOverlay(message: "Analyzing screenshot...")
}
