//
//  EntryView.swift
//  CareThread
//
//  Created by Gian Ramirez on 3/18/26.
//

import SwiftUI
import SwiftData
import PhotosUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
typealias UIImage = NSImage
#endif

struct EntryView: View {
    @Binding var currentMonday: Date
    @Binding var activeDay: Int

    @Environment(\.modelContext) private var modelContext
    @Environment(ClaudeAPIService.self) var apiService

    @Query private var allWeeks: [WeekEntry]

    // MARK: - Local State

    @State private var morningNote = ""
    @State private var eveningNote = ""
    @State private var wakeUpTime = ""
    @State private var bedTime = ""
    @State private var inputText = ""
    @State private var inputMode: InputMode = .text
    @State private var selectedImage: UIImage?
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var healthStatus: HealthStatus = .healthy
    @State private var healthSymptoms = ""
    @State private var therapySessions: [TherapyEntry] = []
    @State private var toastMessage: String?
    @State private var toastIsError = false

    enum InputMode: String, CaseIterable {
        case text = "Paste Text"
        case image = "Screenshot"
    }

    private var weekKey: String { DateHelpers.weekKey(for: currentMonday) }
    private var currentWeek: WeekEntry? { allWeeks.first { $0.weekId == weekKey } }
    private var dayName: String { DateHelpers.dayNames[activeDay] }
    private var isWeekend: Bool { DateHelpers.isWeekend(activeDay) }
    private var hasParsedData: Bool { currentWeek?.parsedEntries[dayName] != nil }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                daySelectorTabs

                if isWeekend {
                    weekendSection
                } else {
                    morningCheckInSection

                    if hasParsedData {
                        parsedResultsSection
                    } else {
                        daycareInputSection
                    }
                }

                healthSection
                therapySection
                eveningSection
            }
            .padding()
        }
        .toast(message: $toastMessage, isError: toastIsError)
        .onChange(of: activeDay) { _, _ in loadExistingData() }
        .onAppear { loadExistingData() }
    }

    // MARK: - Day Selector Tabs

    private var daySelectorTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { dayIndex in
                    let name = DateHelpers.dayNames[dayIndex]
                    let filled = currentWeek?.hasData(for: name) ?? false

                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { activeDay = dayIndex }
                    } label: {
                        VStack(spacing: 4) {
                            Text(DateHelpers.dayTabLabel(dayIndex: dayIndex, monday: currentMonday))
                                .font(.caption.weight(activeDay == dayIndex ? .bold : .regular))
                            Circle()
                                .fill(filled ? AppTheme.green : Color.clear)
                                .frame(width: 6, height: 6)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(activeDay == dayIndex ? AppTheme.accentSoft : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Morning Check-In (auto-saves on blur)

    private var morningCheckInSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Morning Check-In").font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text("Wake Up").font(.caption.weight(.medium))
                TextField("e.g. 6:30", text: $wakeUpTime)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numbersAndPunctuation)
                    .onSubmit { autoSaveSleep() }
                    .onChange(of: wakeUpTime) { _, _ in debounceAutoSaveSleep() }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Morning Note").font(.subheadline.weight(.medium))
                TextEditor(text: $morningNote)
                    .frame(minHeight: 60)
                    .padding(8)
                    .background(AppTheme.inputBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border, lineWidth: 1))
                    .onChange(of: morningNote) { _, _ in debounceAutoSaveNotes() }
            }
        }
        .cardStyle()
    }

    // MARK: - Daycare Input (still needs explicit "Log" button for Claude parsing)

    private var daycareInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Input Mode", selection: $inputMode) {
                ForEach(InputMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if inputMode == .text {
                textInputArea
            } else {
                imageInputArea
            }

            Button {
                Task { await parseEntry() }
            } label: {
                Label(
                    apiService.isLoading ? "Processing..." : "Log This Day",
                    systemImage: "doc.text.magnifyingglass"
                )
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(apiService.isLoading && inputText.isEmpty && selectedImage == nil)
        }
        .cardStyle()
    }

    private var textInputArea: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Paste daycare sheet text")
                .font(.subheadline.weight(.medium))
            TextEditor(text: $inputText)
                .frame(minHeight: 120)
                .padding(8)
                .background(AppTheme.inputBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border, lineWidth: 1))
        }
    }

    private var imageInputArea: some View {
        VStack(spacing: 12) {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Button("Remove", role: .destructive) {
                    selectedImage = nil
                    photoPickerItem = nil
                }
                .font(.caption)
            }

            PhotosPicker(
                selection: $photoPickerItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Label(
                    selectedImage == nil ? "Select Screenshot" : "Change Screenshot",
                    systemImage: "photo"
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
            .onChange(of: photoPickerItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        selectedImage = uiImage
                    }
                }
            }
        }
    }

    // MARK: - Parsed Results

    private var parsedResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let parsed = currentWeek?.parsedEntries[dayName] {
                categoryResult(icon: "fork.knife", label: "Eating", data: parsed.eating)
                categoryResult(icon: "bed.double.fill", label: "Naps", data: parsed.naps)
                categoryResult(icon: "drop.fill", label: "Potty", data: parsed.potty)

                HStack {
                    Image(systemName: "face.smiling")
                        .foregroundStyle(AppTheme.color(for: parsed.moodRating))
                    Text("Mood").font(.subheadline.weight(.semibold))
                    Spacer()
                    StatusLabel(rating: parsed.moodRating)
                }
                Text(parsed.mood)
                    .font(.subheadline).foregroundStyle(.secondary)

                if !parsed.activities.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Activities").font(.subheadline.weight(.semibold))
                        ForEach(parsed.activities, id: \.self) { activity in
                            HStack(alignment: .top, spacing: 6) {
                                Text("•").foregroundStyle(.secondary)
                                Text(activity).font(.subheadline)
                            }
                        }
                    }
                }

                if !parsed.teacherNotes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Teacher Notes").font(.subheadline.weight(.semibold))
                        Text(parsed.teacherNotes).font(.subheadline).foregroundStyle(.secondary)
                    }
                }

                Button("Re-enter This Day", role: .destructive) {
                    currentWeek?.parsedEntries.removeValue(forKey: dayName)
                    currentWeek?.entries.removeValue(forKey: dayName)
                    currentWeek?.updatedAt = Date()
                }
                .font(.caption)
            }
        }
        .cardStyle()
    }

    private func categoryResult(icon: String, label: String, data: CategoryData) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(AppTheme.color(for: data.rating))
                Text(label).font(.subheadline.weight(.semibold))
                Spacer()
                StatusLabel(rating: data.rating)
            }
            Text(data.summary).font(.subheadline).foregroundStyle(.secondary)
            ForEach(data.details, id: \.self) { detail in
                HStack(alignment: .top, spacing: 6) {
                    Text("–").foregroundStyle(.tertiary)
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Weekend

    private var weekendSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Weekend — Home Tracking Only", systemImage: "house.fill")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text("No daycare sheet needed. Use health, therapy, notes, and sleep fields to track the day at home.")
                .font(.caption).foregroundStyle(.tertiary)
        }
        .cardStyle()
    }

    // MARK: - Health Section (auto-saves)

    private var healthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.text.clipboard")
                    .foregroundStyle(AppTheme.color(for: healthStatus.rating))
                Text("Health").font(.headline)
            }

            Picker("Status", selection: $healthStatus) {
                ForEach(HealthStatus.allCases) { status in
                    Text(status.rawValue).tag(status)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: healthStatus) { _, _ in autoSaveHealth() }

            if healthStatus != .healthy {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Symptoms").font(.subheadline.weight(.medium))
                    TextEditor(text: $healthSymptoms)
                        .frame(minHeight: 60)
                        .padding(8)
                        .background(AppTheme.inputBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border, lineWidth: 1))
                        .onChange(of: healthSymptoms) { _, _ in debounceAutoSaveHealth() }
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Therapy Section (auto-saves)

    private var therapySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "figure.walk")
                    .foregroundStyle(AppTheme.accent)
                Text("Therapy").font(.headline)
                Spacer()
                Button {
                    therapySessions.append(TherapyEntry())
                    autoSaveTherapy()
                } label: {
                    Label("Add Session", systemImage: "plus.circle.fill")
                        .font(.subheadline)
                }
            }

            if therapySessions.isEmpty {
                Text("No therapy sessions logged. Tap + to add one.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            ForEach($therapySessions) { $session in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Picker("Type", selection: $session.type) {
                            ForEach(TherapyType.allCases) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: session.type) { _, _ in autoSaveTherapy() }

                        Button(role: .destructive) {
                            therapySessions.removeAll { $0.id == session.id }
                            autoSaveTherapy()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }

                    TextEditor(text: $session.notes)
                        .frame(minHeight: 50)
                        .padding(8)
                        .background(AppTheme.inputBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border, lineWidth: 1))
                        .overlay(alignment: .topLeading) {
                            if session.notes.isEmpty {
                                Text("What was worked on, progress notes...")
                                    .font(.subheadline)
                                    .foregroundStyle(.tertiary)
                                    .padding(.leading, 12)
                                    .padding(.top, 16)
                                    .allowsHitTesting(false)
                            }
                        }
                        .onChange(of: session.notes) { _, _ in debounceAutoSaveTherapy() }
                }
                .padding(8)
                .background(Color(.tertiarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .cardStyle()
    }

    // MARK: - Evening (auto-saves)

    private var eveningSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Evening").font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text("Bed Time").font(.caption.weight(.medium))
                TextField("e.g. 8:00", text: $bedTime)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numbersAndPunctuation)
                    .onSubmit { autoSaveSleep() }
                    .onChange(of: bedTime) { _, _ in debounceAutoSaveSleep() }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Evening Note").font(.subheadline.weight(.medium))
                TextEditor(text: $eveningNote)
                    .frame(minHeight: 80)
                    .padding(8)
                    .background(AppTheme.inputBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border, lineWidth: 1))
                    .onChange(of: eveningNote) { _, _ in debounceAutoSaveNotes() }
            }
        }
        .cardStyle()
    }

    // MARK: - Auto-Save Logic

    @State private var saveTask: Task<Void, Never>?

    private func debounceAutoSaveNotes() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            autoSaveNotes()
        }
    }

    private func debounceAutoSaveSleep() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            autoSaveSleep()
        }
    }

    private func debounceAutoSaveHealth() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            autoSaveHealth()
        }
    }

    private func debounceAutoSaveTherapy() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            autoSaveTherapy()
        }
    }

    private func autoSaveNotes() {
        let week = getOrCreateWeek()
        var changed = false
        if morningNote != (week.morningNotes[dayName] ?? "") {
            week.morningNotes[dayName] = morningNote.isEmpty ? nil : morningNote
            changed = true
        }
        if eveningNote != (week.eveningNotes[dayName] ?? "") {
            week.eveningNotes[dayName] = eveningNote.isEmpty ? nil : eveningNote
            changed = true
        }
        if changed {
            week.updatedAt = Date()
            showSavedToast()
        }
    }

    private func autoSaveSleep() {
        let week = getOrCreateWeek()
        let existing = week.sleepNotes[dayName]
        let newWake = wakeUpTime.isEmpty ? (existing?.wakeUp ?? "") : wakeUpTime
        let newBed = bedTime.isEmpty ? (existing?.bedTime ?? "") : bedTime

        if newWake.isEmpty && newBed.isEmpty {
            if existing != nil {
                week.sleepNotes.removeValue(forKey: dayName)
                week.updatedAt = Date()
                showSavedToast()
            }
        } else if newWake != (existing?.wakeUp ?? "") || newBed != (existing?.bedTime ?? "") {
            week.sleepNotes[dayName] = SleepData(wakeUp: newWake, bedTime: newBed)
            week.updatedAt = Date()
            showSavedToast()
        }
    }

    private func autoSaveHealth() {
        let week = getOrCreateWeek()
        let data = HealthData(status: healthStatus, symptoms: healthSymptoms)
        if data.isEmpty {
            if week.healthNotes[dayName] != nil {
                week.healthNotes.removeValue(forKey: dayName)
                week.updatedAt = Date()
            }
        } else {
            week.healthNotes[dayName] = data
            week.updatedAt = Date()
            showSavedToast()
        }
    }

    private func autoSaveTherapy() {
        let week = getOrCreateWeek()
        let nonEmpty = therapySessions.filter { !$0.isEmpty }
        if nonEmpty.isEmpty {
            if week.therapyNotes[dayName] != nil {
                week.therapyNotes.removeValue(forKey: dayName)
                week.updatedAt = Date()
            }
        } else {
            week.therapyNotes[dayName] = therapySessions
            week.updatedAt = Date()
            showSavedToast()
        }
    }

    private func showSavedToast() {
        toastIsError = false
        toastMessage = "Saved"
    }

    // MARK: - Parse Entry (explicit action — sends to Claude)

    private func parseEntry() async {
        let week = getOrCreateWeek()

        // Auto-save morning data before parsing
        if !morningNote.isEmpty { week.morningNotes[dayName] = morningNote }
        if !wakeUpTime.isEmpty {
            let existingBed = week.sleepNotes[dayName]?.bedTime ?? ""
            week.sleepNotes[dayName] = SleepData(wakeUp: wakeUpTime, bedTime: existingBed)
        }

        do {
            let parsed: ParsedDayData
            let contextPrefix = buildMorningContext()
            if inputMode == .text {
                guard !inputText.isEmpty else { return }
                let enrichedText = contextPrefix.isEmpty
                    ? inputText
                    : contextPrefix + "\n\nDAYCARE SHEET:\n" + inputText
                parsed = try await apiService.parseDayEntry(text: enrichedText)
                week.entries[dayName] = inputText
            } else {
                guard let image = selectedImage else { return }
                parsed = try await apiService.parseDayEntry(image: image)
                week.entries[dayName] = "[Screenshot]"
            }
            week.parsedEntries[dayName] = parsed
            week.updatedAt = Date()
            inputText = ""; selectedImage = nil; photoPickerItem = nil
            toastIsError = false; toastMessage = "\(dayName) logged!"
        } catch {
            toastIsError = true; toastMessage = "Couldn't parse that — try again."
        }
    }

    private func buildMorningContext() -> String {
        var context = ""
        if !morningNote.isEmpty {
            context += "PARENT MORNING NOTE: \(morningNote)\n"
        }
        if !wakeUpTime.isEmpty {
            context += "WAKE UP TIME: \(wakeUpTime)\n"
        }
        return context
    }

    // MARK: - Load / Create

    private func loadExistingData() {
        morningNote = currentWeek?.morningNotes[dayName] ?? ""
        eveningNote = currentWeek?.eveningNotes[dayName] ?? ""
        wakeUpTime = currentWeek?.sleepNotes[dayName]?.wakeUp ?? ""
        bedTime = currentWeek?.sleepNotes[dayName]?.bedTime ?? ""
        healthStatus = currentWeek?.healthNotes[dayName]?.status ?? .healthy
        healthSymptoms = currentWeek?.healthNotes[dayName]?.symptoms ?? ""
        therapySessions = currentWeek?.therapyNotes[dayName] ?? []
        inputText = ""; selectedImage = nil
    }

    private func getOrCreateWeek() -> WeekEntry {
        if let existing = currentWeek { return existing }
        let newWeek = WeekEntry(weekId: weekKey)
        modelContext.insert(newWeek)
        return newWeek
    }
}

#Preview {
    EntryView(
        currentMonday: .constant(DateHelpers.mondayOfWeek(containing: Date())),
        activeDay: .constant(0)
    )
    .environment(ClaudeAPIService())
    .modelContainer(SampleData.previewContainer)
}
