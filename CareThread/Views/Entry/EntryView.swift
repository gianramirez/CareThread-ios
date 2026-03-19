import SwiftUI
import SwiftData
import PhotosUI

// MARK: - EntryView (Log Day)
// ─────────────────────────────────────────────────────────────────────
// Maps to your React "Log Day" tab — the entry form for daily data.
//
// This is the most interactive view. In React it was a massive chunk
// of App.jsx with conditional rendering based on:
//   1. Whether the day already has data (show parsed results)
//   2. Whether it's a weekend (home-only tracking)
//   3. Input mode (text vs screenshot)
//
// NEW SWIFTUI CONCEPTS:
//
// PhotosPicker: Native iOS photo picker — no need for <input type="file">
//   hacks or third-party libraries. It's a SwiftUI view that presents
//   the system photo picker automatically.
//
// @State vs @Binding:
//   - @State: This view OWNS the data (like useState in React)
//   - @Binding: Parent OWNS the data, this view just reads/writes it
//     (like passing [value, setValue] as a prop)
//
// TextEditor: SwiftUI's <textarea> equivalent. Unlike TextField (which
//   is <input type="text">), TextEditor is multiline.
// ─────────────────────────────────────────────────────────────────────

struct EntryView: View {
    @Binding var currentMonday: Date
    @Binding var activeDay: Int

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var apiService: ClaudeAPIService

    @Query private var allWeeks: [WeekEntry]

    // Local state for the entry form
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

    // MARK: - Computed

    private var weekKey: String {
        DateHelpers.weekKey(for: currentMonday)
    }

    private var currentWeek: WeekEntry? {
        allWeeks.first { $0.weekId == weekKey }
    }

    private var dayName: String {
        DateHelpers.dayNames[activeDay]
    }

    private var isWeekend: Bool {
        DateHelpers.isWeekend(activeDay)
    }

    private var hasParsedData: Bool {
        currentWeek?.parsedEntries[dayName] != nil
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Day selector tabs (M T W T F S S)
                daySelectorTabs

                // Main content based on state
                if hasParsedData {
                    parsedResultsSection
                } else if isWeekend {
                    weekendSection
                } else {
                    entryInputSection
                }

                // Sleep & evening notes (always shown)
                sleepAndNotesSection
            }
            .padding()
        }
        .toast(message: $toastMessage, isError: toastIsError)
        // Load existing data when day changes
        .onChange(of: activeDay) { _, _ in loadExistingData() }
        .onAppear { loadExistingData() }
    }

    // MARK: - Day Selector Tabs

    /// Horizontal scrollable day tabs — maps to your React day selector.
    /// In React: clickable tabs with green dots for filled days.
    private var daySelectorTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { dayIndex in
                    let name = DateHelpers.dayNames[dayIndex]
                    let filled = currentWeek?.hasData(for: name) ?? false

                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            activeDay = dayIndex
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text(DateHelpers.dayTabLabel(dayIndex: dayIndex, monday: currentMonday))
                                .font(.caption.weight(activeDay == dayIndex ? .bold : .regular))

                            if filled {
                                Circle()
                                    .fill(AppTheme.green)
                                    .frame(width: 6, height: 6)
                            } else {
                                Circle()
                                    .fill(Color.clear)
                                    .frame(width: 6, height: 6)
                            }
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

    // MARK: - Entry Input (Weekday, no existing data)

    /// The main entry form — paste text or upload screenshot.
    /// Maps to your React entry form with inputMode toggle.
    private var entryInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Morning note
            VStack(alignment: .leading, spacing: 4) {
                Text("Morning Note (optional)")
                    .font(.subheadline.weight(.medium))
                TextEditor(text: $morningNote)
                    .frame(minHeight: 60)
                    .padding(8)
                    .background(AppTheme.inputBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppTheme.border, lineWidth: 1)
                    )
            }

            Divider()

            // Input mode toggle — like your React radio buttons
            // Picker with .segmented style maps to your toggle buttons
            Picker("Input Mode", selection: $inputMode) {
                ForEach(InputMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            // Conditional content based on mode
            if inputMode == .text {
                textInputArea
            } else {
                imageInputArea
            }

            // Submit button
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

    // MARK: - Text Input

    private var textInputArea: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Paste daycare sheet text")
                .font(.subheadline.weight(.medium))
            TextEditor(text: $inputText)
                .frame(minHeight: 120)
                .padding(8)
                .background(AppTheme.inputBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppTheme.border, lineWidth: 1)
                )
        }
    }

    // MARK: - Image Input

    /// Screenshot upload — uses iOS native PhotosPicker.
    /// In React you used <input type="file"> with FileReader.
    /// PhotosPicker is WAY cleaner — it handles permissions, UI, and
    /// returns the image directly.
    private var imageInputArea: some View {
        VStack(spacing: 12) {
            if let image = selectedImage {
                // Preview the selected image
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

            // PhotosPicker is a SwiftUI view that opens the system photo picker
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
            // When user picks a photo, load it as UIImage
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

    // MARK: - Parsed Results (day has data)

    /// Shows the parsed daycare data — maps to your React parsed results display.
    /// Shown when `parsedEntries[day]` exists.
    private var parsedResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let parsed = currentWeek?.parsedEntries[dayName] {
                // Category summaries
                categoryResult(icon: "🍽", label: "Eating", data: parsed.eating)
                categoryResult(icon: "😴", label: "Naps", data: parsed.naps)
                categoryResult(icon: "🚽", label: "Potty", data: parsed.potty)

                // Mood
                HStack {
                    Text("😊")
                    Text("Mood")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    StatusLabel(rating: parsed.moodRating)
                }
                Text(parsed.mood)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Activities
                if !parsed.activities.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Activities")
                            .font(.subheadline.weight(.semibold))
                        ForEach(parsed.activities, id: \.self) { activity in
                            HStack(alignment: .top, spacing: 6) {
                                Text("•")
                                    .foregroundStyle(.secondary)
                                Text(activity)
                                    .font(.subheadline)
                            }
                        }
                    }
                }

                // Teacher notes
                if !parsed.teacherNotes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Teacher Notes")
                            .font(.subheadline.weight(.semibold))
                        Text(parsed.teacherNotes)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                // Re-enter button
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

    /// A single category result row (eating/naps/potty)
    private func categoryResult(icon: String, label: String, data: CategoryData) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(icon)
                Text(label)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                StatusLabel(rating: data.rating)
            }
            Text(data.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ForEach(data.details, id: \.self) { detail in
                HStack(alignment: .top, spacing: 6) {
                    Text("–")
                        .foregroundStyle(.tertiary)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Weekend Section

    /// Simplified home-only tracking for weekends.
    /// In React: shown when dayIndex >= 5 and no parsed data.
    private var weekendSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Weekend — Home Tracking Only", systemImage: "house.fill")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Text("No daycare sheet needed. Use the notes and sleep fields below to track the day at home.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .cardStyle()
    }

    // MARK: - Sleep & Notes (always shown)

    /// Sleep times + evening note — shown for every day type.
    private var sleepAndNotesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Home & Sleep")
                .font(.headline)

            // Sleep times
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Wake Up")
                        .font(.caption.weight(.medium))
                    TextField("e.g. 6:30", text: $wakeUpTime)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numbersAndPunctuation)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Bed Time")
                        .font(.caption.weight(.medium))
                    TextField("e.g. 8:00", text: $bedTime)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numbersAndPunctuation)
                }
            }

            // Evening note
            VStack(alignment: .leading, spacing: 4) {
                Text("Evening Note")
                    .font(.subheadline.weight(.medium))
                TextEditor(text: $eveningNote)
                    .frame(minHeight: 80)
                    .padding(8)
                    .background(AppTheme.inputBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppTheme.border, lineWidth: 1)
                    )
            }

            // Save button
            Button {
                saveHomeAndSleep()
            } label: {
                Label("Save Home & Sleep", systemImage: "checkmark.circle")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
        }
        .cardStyle()
    }

    // MARK: - Actions

    /// Parse the daycare entry via Claude API.
    /// Maps to your React parseEntry() function.
    private func parseEntry() async {
        // Get or create the week entry
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

            // Store parsed data
            week.parsedEntries[dayName] = parsed

            // Save morning note if provided
            if !morningNote.isEmpty {
                week.morningNotes[dayName] = morningNote
            }

            week.updatedAt = Date()

            // Clear input fields
            inputText = ""
            morningNote = ""
            selectedImage = nil
            photoPickerItem = nil

            toastIsError = false
            toastMessage = "\(dayName) logged!"
        } catch {
            toastIsError = true
            toastMessage = "Couldn't parse that — try again."
            print("Parse error: \(error)")
        }
    }

    /// Save evening note and sleep data.
    /// Maps to your React saveEveningNote() and saveSleepNote().
    private func saveHomeAndSleep() {
        let week = getOrCreateWeek()

        if !eveningNote.isEmpty {
            week.eveningNotes[dayName] = eveningNote
        }
        if !wakeUpTime.isEmpty || !bedTime.isEmpty {
            week.sleepNotes[dayName] = SleepData(wakeUp: wakeUpTime, bedTime: bedTime)
        }

        week.updatedAt = Date()
        toastIsError = false
        toastMessage = "Saved!"
    }

    /// Load existing data when switching days.
    private func loadExistingData() {
        eveningNote = currentWeek?.eveningNotes[dayName] ?? ""
        morningNote = currentWeek?.morningNotes[dayName] ?? ""
        wakeUpTime = currentWeek?.sleepNotes[dayName]?.wakeUp ?? ""
        bedTime = currentWeek?.sleepNotes[dayName]?.bedTime ?? ""
        inputText = ""
        selectedImage = nil
    }

    /// Get existing WeekEntry or create a new one.
    /// In React, your persistWeek() used Supabase UPSERT.
    /// In SwiftData, we check if it exists and insert if not.
    private func getOrCreateWeek() -> WeekEntry {
        if let existing = currentWeek {
            return existing
        }
        let newWeek = WeekEntry(weekId: weekKey)
        modelContext.insert(newWeek)
        return newWeek
    }
}
