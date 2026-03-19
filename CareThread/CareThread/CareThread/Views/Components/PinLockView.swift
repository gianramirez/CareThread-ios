import SwiftUI

// MARK: - PinLockView
// ─────────────────────────────────────────────────────────────────────
// Maps to your React PinScreen component.
//
// In React: Shown when unlocked === false, checks against settings.pin_code
// In SwiftUI: This is a full-screen view shown via .fullScreenCover()
//
// New SwiftUI concepts here:
// - @State: Local component state (like useState in React)
// - @FocusState: Controls keyboard focus (no React equivalent — you'd
//   use refs and .focus() manually)
// - @Binding: A two-way reference to parent state (like passing a
//   setState function as a prop in React, but with cleaner syntax)
// ─────────────────────────────────────────────────────────────────────

struct PinLockView: View {
    let correctPin: String
    @Binding var isUnlocked: Bool

    @State private var enteredPin = ""
    @State private var showError = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // App icon / header
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 60))
                .foregroundStyle(AppTheme.accent)

            Text("CareThread")
                .font(.title.weight(.bold))

            Text("Enter your PIN to unlock")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // PIN input field
            SecureField("PIN", text: $enteredPin)
                .keyboardType(.numberPad)
                .textContentType(.password)
                .multilineTextAlignment(.center)
                .font(.title2.monospaced())
                .padding()
                .background(AppTheme.inputBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .frame(maxWidth: 200)
                .focused($isFocused)
                .onSubmit { checkPin() }
                .onChange(of: enteredPin) { _, newValue in
                    // Auto-submit when PIN length matches
                    if newValue.count >= correctPin.count {
                        checkPin()
                    }
                }

            if showError {
                Text("Incorrect PIN")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .transition(.opacity)
            }

            // Unlock button
            Button {
                checkPin()
            } label: {
                Text("Unlock")
                    .font(.headline)
                    .frame(maxWidth: 200)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(enteredPin.isEmpty)

            Spacer()
            Spacer()
        }
        .padding()
        .onAppear {
            // Auto-focus the PIN field when view appears
            isFocused = true
        }
    }

    private func checkPin() {
        if enteredPin == correctPin {
            withAnimation {
                isUnlocked = true
            }
        } else {
            withAnimation {
                showError = true
                enteredPin = ""
            }
            // Clear error after 2 seconds
            Task {
                try? await Task.sleep(for: .seconds(2))
                withAnimation { showError = false }
            }
        }
    }
}

#Preview {
    PinLockView(correctPin: "1234", isUnlocked: .constant(false))
}
