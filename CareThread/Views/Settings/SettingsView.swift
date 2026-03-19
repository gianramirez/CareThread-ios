//
//  SettingsView.swift
//  CareThread
//
//  Created by Gian Ramirez on 3/18/26.
//

import SwiftUI
import SwiftData

// MARK: - SettingsView
// Maps to your React Settings tab with routine, appointments, therapy, PIN.

struct SettingsView: View {
    @Binding var currentMonday: Date
    @Binding var isUnlocked: Bool

    @Environment(\.modelContext) private var modelContext
    @Query private var allSettings: [AppSettings]
    @Query private var allWeeks: [WeekEntry]

    @State private var toastMessage: String?
    @State private var toastIsError = false
    @State private var showClearConfirm = false
    @State private var newPin = ""

    @State private var editedRoutine: [String: String] = [:]
    @State private var editedAppointments: [String: String] = [:]
    @State private var editedTherapy = ""

    private var settings: AppSettings? { allSettings.first }

    var body: some View {
        Form {
            Section {
                ForEach(DateHelpers.weekdayNames, id: \.self) { day in
                    HStack {
                        Text(day).frame(width: 90, alignment: .leading)

                        Picker("", selection: routineBinding(for: day)) {
                            ForEach(DayLocation.allCases) { location in
                                Text(location.displayName).tag(location.rawValue)
                            }
                        }
                        .pickerStyle(.menu)

                        TextField("Appointments", text: appointmentBinding(for: day))
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                    }
                }
            } header: {
                Text("Weekly Routine")
            } footer: {
                Text("Set the default location and any recurring appointments for each day.")
            }

            Section {
                TextEditor(text: $editedTherapy)
                    .frame(minHeight: 80)
            } header: {
                Text("Therapy Schedule")
            } footer: {
                Text("Free-text schedule (e.g., \"OT Mondays 10am, Speech Thursdays 2pm\"). Included in report context.")
            }

            Section {
                HStack {
                    SecureField("New PIN (4-8 digits)", text: $newPin)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)

                    Button("Update") { updatePin() }
                        .disabled(newPin.count < 4 || newPin.count > 8)
                }
            } header: {
                Text("PIN Lock")
            } footer: {
                Text(settings?.pinCode.isEmpty ?? true
                    ? "No PIN set. Anyone can open the app."
                    : "PIN is set. Change it or leave blank to remove.")
            }

            Section {
                Button {
                    saveSettings()
                } label: {
                    Label("Save Settings", systemImage: "checkmark.circle.fill")
                }

                Button(role: .destructive) {
                    showClearConfirm = true
                } label: {
                    Label("Clear This Week", systemImage: "trash")
                }

                if !(settings?.pinCode.isEmpty ?? true) {
                    Button {
                        isUnlocked = false
                    } label: {
                        Label("Lock App", systemImage: "lock.fill")
                    }
                }
            } header: {
                Text("Actions")
            }
        }
        .toast(message: $toastMessage, isError: toastIsError)
        .onAppear { loadSettings() }
        .confirmationDialog(
            "Clear all data for this week?",
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button("Clear Week", role: .destructive) { clearWeek() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete all entries, notes, and reports for the current week. This cannot be undone.")
        }
    }

    private func routineBinding(for day: String) -> Binding<String> {
        Binding(get: { editedRoutine[day] ?? "" }, set: { editedRoutine[day] = $0 })
    }

    private func appointmentBinding(for day: String) -> Binding<String> {
        Binding(get: { editedAppointments[day] ?? "" }, set: { editedAppointments[day] = $0 })
    }

    private func loadSettings() {
        if let s = settings {
            editedRoutine = s.routine
            editedAppointments = s.appointments
            editedTherapy = s.therapySchedule
        }
    }

    private func saveSettings() {
        let s = getOrCreateSettings()
        s.routine = editedRoutine
        s.appointments = editedAppointments
        s.therapySchedule = editedTherapy
        s.updatedAt = Date()
        toastIsError = false; toastMessage = "Settings saved!"
    }

    private func updatePin() {
        let s = getOrCreateSettings()
        s.pinCode = newPin
        s.updatedAt = Date()
        newPin = ""
        toastIsError = false; toastMessage = "PIN updated!"
    }

    private func clearWeek() {
        let key = DateHelpers.weekKey(for: currentMonday)
        if let week = allWeeks.first(where: { $0.weekId == key }) {
            modelContext.delete(week)
            toastIsError = false; toastMessage = "Week cleared!"
        }
    }

    private func getOrCreateSettings() -> AppSettings {
        if let existing = settings { return existing }
        let newSettings = AppSettings()
        modelContext.insert(newSettings)
        return newSettings
    }
}
