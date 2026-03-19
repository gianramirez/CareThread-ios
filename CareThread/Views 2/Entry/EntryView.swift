//
//  EntryView.swift
//  CareThread
//
//  Created by Gian Ramirez on 3/18/26.
//

import SwiftUI
import SwiftData
import PhotosUI

// MARK: - EntryView (Log Day)
// Maps to your React "Log Day" tab — the entry form for daily data.

struct EntryView: View {
    @Binding var currentMonday: Date
    @Binding var activeDay: Int

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var apiService: ClaudeAPIService

    @Query private var allWeeks: [WeekEntry]

    @State private var inputText = ""
    @State private var morningNote = ""
    @State private var eveningNote = ""
    @State private var wakeUpTime = ""
    @State private var bedTime = ""
    @State private var inputMode: InputMode = .text
    @State private var selectedImage: UIImage?
    @State private var photoPickerItem: PhotosPickerItem?
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

                if hasParsedData {
                    parsedResultsSection
                } else if isWeekend {
                    weekendSection
                } else {
                    entryInputSection
                }

                sleepAndNotesSection
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

    // MARK: - Entry Input

    private var entryInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Morning Note (optional)")
                    .font(.subheadline.weight(.medium))
                TextEditor(text: $morningNote)
                    .frame(minHeight: 60)
                    .padding(8)
                    .background(AppTheme.inputBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border, lineWidth: 1))
            }

            Divider()

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
                categoryResult(icon: "🍽", label: "Eating", data: parsed.eating)
                categoryResult(icon: "😴", label: "Naps", data: parsed.naps)
                categoryResult(icon: "🚽", label: "Potty", data: parsed.potty)

                HStack {
                    Text("😊")
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
                Text(icon)
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
            Text("No daycare sheet needed. Use the notes and sleep fields below to track the day at home.")
                .font(.caption).foregroundStyle(.tertiary)
        }
        .cardStyle()
    }

    // MARK: - Sleep & Notes

    private var sleepAndNotesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Home & Sleep").font(.headline)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Wake Up").font(.caption.weight(.medium))
                    TextField("e.g. 6:30", text: $wakeUpTime)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numbersAndPunctuation)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bed Time").font(.caption.weight(.medium))
                    TextField("e.g. 8:00", text: $bedTime)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numbersAndPunctuation)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Evening Note").font(.subheadline.weight(.medium))
                TextEditor(text: $eveningNote)
                    .frame(minHeight: 80)
                    .padding(8)
                    .background(AppTheme.inputBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border, lineWidth: 1))
            }

            Button {
                saveHomeAndSleep()
            } label: {
                Label("Save Home & Sleep", systemImage: "checkmark.circle")
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
        }
        .cardStyle()
    }

    // MARK: - Actions

    private func parseEntry() async {
        let week = getOrCreateWeek()
        do {
            let parsed: ParsedDayData
            if inputMode == .text {
                guard !inputText.isEmpty else { return }
                parsed = try await apiService.parseDayEntry(text: inputText)
                week.entries[dayName] = inputText
            } else {
                guard let image = selectedImage else { return }
                parsed = try await apiService.parseDayEntry(image: image)
                week.entries[dayName] = "[Screenshot]"
            }
            week.parsedEntries[dayName] = parsed
            if !morningNote.isEmpty { week.morningNotes[dayName] = morningNote }
            week.updatedAt = Date()
            inputText = ""; morningNote = ""; selectedImage = nil; photoPickerItem = nil
            toastIsError = false; toastMessage = "\(dayName) logged!"
        } catch {
            toastIsError = true; toastMessage = "Couldn't parse that — try again."
            print("Parse error: \(error)")
        }
    }

    private func saveHomeAndSleep() {
        let week = getOrCreateWeek()
        if !eveningNote.isEmpty { week.eveningNotes[dayName] = eveningNote }
        if !wakeUpTime.isEmpty || !bedTime.isEmpty {
            week.sleepNotes[dayName] = SleepData(wakeUp: wakeUpTime, bedTime: bedTime)
        }
        week.updatedAt = Date()
        toastIsError = false; toastMessage = "Saved!"
    }

    private func loadExistingData() {
        eveningNote = currentWeek?.eveningNotes[dayName] ?? ""
        morningNote = currentWeek?.morningNotes[dayName] ?? ""
        wakeUpTime = currentWeek?.sleepNotes[dayName]?.wakeUp ?? ""
        bedTime = currentWeek?.sleepNotes[dayName]?.bedTime ?? ""
        inputText = ""; selectedImage = nil
    }

    private func getOrCreateWeek() -> WeekEntry {
        if let existing = currentWeek { return existing }
        let newWeek = WeekEntry(weekId: weekKey)
        modelContext.insert(newWeek)
        return newWeek
    }
}
