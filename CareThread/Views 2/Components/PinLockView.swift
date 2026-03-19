//
//  PinLockView.swift
//  CareThread
//
//  Created by Gian Ramirez on 3/18/26.
//

import SwiftUI

// MARK: - PinLockView
// Maps to your React PinScreen component.

struct PinLockView: View {
    let correctPin: String
    @Binding var isUnlocked: Bool

    @State private var enteredPin = ""
    @State private var showError = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 60))
                .foregroundStyle(AppTheme.accent)

            Text("CareThread")
                .font(.title.weight(.bold))

            Text("Enter your PIN to unlock")
                .font(.subheadline)
                .foregroundStyle(.secondary)

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
        .onAppear { isFocused = true }
    }

    private func checkPin() {
        if enteredPin == correctPin {
            withAnimation { isUnlocked = true }
        } else {
            withAnimation {
                showError = true
                enteredPin = ""
            }
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
