//
//  BiometricLockView.swift
//  CareThread
//
//  Created by Gian Ramirez on 3/18/26.
//

import SwiftUI
import LocalAuthentication

struct BiometricLockView: View {
    @Binding var isUnlocked: Bool

    @State private var authError: String?

    private var biometricType: LABiometryType {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
        return context.biometryType
    }

    private var biometricLabel: String {
        switch biometricType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        case .none: return "Passcode"
        @unknown default: return "Biometrics"
        }
    }

    private var biometricIcon: String {
        switch biometricType {
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        case .opticID: return "opticid"
        case .none: return "lock.shield.fill"
        @unknown default: return "lock.shield.fill"
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: biometricIcon)
                .font(.system(size: 60))
                .foregroundStyle(AppTheme.accent)
                .symbolEffect(.pulse, options: .repeating)

            Text("CareThread")
                .font(.title.weight(.bold))

            Text("Unlock with \(biometricLabel)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let error = authError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .transition(.opacity)
            }

            Button {
                authenticate()
            } label: {
                Label("Unlock", systemImage: biometricIcon)
                    .font(.headline)
                    .frame(maxWidth: 200)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)

            Spacer()
            Spacer()
        }
        .padding()
        .onAppear {
            authenticate()
        }
    }

    private func authenticate() {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Unlock CareThread to access your child's data"
            ) { success, authenticationError in
                if success {
                    withAnimation { isUnlocked = true }
                } else {
                    if let laError = authenticationError as? LAError {
                        switch laError.code {
                        case .userCancel, .appCancel, .systemCancel:
                            break
                        case .biometryNotEnrolled:
                            authError = "No biometrics enrolled. Please set up \(biometricLabel) in Settings."
                        case .biometryLockout:
                            authError = "Too many failed attempts. Try again later."
                        default:
                            authError = "Authentication failed. Tap Unlock to try again."
                        }
                    }
                }
            }
        } else {
            withAnimation { isUnlocked = true }
        }
    }
}

#Preview {
    BiometricLockView(isUnlocked: .constant(false))
}
