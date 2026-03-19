import SwiftUI

// MARK: - WeekNavigator
// ─────────────────────────────────────────────────────────────────────
// Maps to your React header with < Week of Jan 15, 2026 > navigation.
//
// In React this was part of the monolithic App.jsx header.
// In SwiftUI we extract it as a reusable component — good practice
// for both frameworks, but SwiftUI's composition model makes it
// more natural.
//
// SwiftUI concept: @Binding
// In React: you'd pass `currentMonday` and `setCurrentMonday` as separate props
// In SwiftUI: @Binding<Date> IS both the value and the setter in one.
// When you write `$currentMonday` (with $), you pass the binding.
// When you write `currentMonday` (without $), you read the value.
// ─────────────────────────────────────────────────────────────────────

struct WeekNavigator: View {
    @Binding var currentMonday: Date
    @State private var showCalendar = false

    private var isCurrentWeek: Bool {
        DateHelpers.weekKey(for: currentMonday)
            == DateHelpers.weekKey(for: DateHelpers.mondayOfWeek(containing: Date()))
    }

    private var canGoForward: Bool {
        !DateHelpers.isFutureWeek(DateHelpers.offsetWeek(currentMonday, by: 1))
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                // Previous week button
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentMonday = DateHelpers.offsetWeek(currentMonday, by: -1)
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3.weight(.semibold))
                }

                Spacer()

                // Week label + calendar dropdown
                Button {
                    showCalendar.toggle()
                } label: {
                    VStack(spacing: 2) {
                        Text("Week of")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(DateHelpers.formatWeekLabel(currentMonday))
                            .font(.headline)
                    }
                }
                .foregroundStyle(.primary)

                Spacer()

                // Next week button
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentMonday = DateHelpers.offsetWeek(currentMonday, by: 1)
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title3.weight(.semibold))
                }
                .disabled(!canGoForward)
                .opacity(canGoForward ? 1 : 0.3)
            }
            .padding(.horizontal)

            // "Today" button (only shows when not on current week)
            if !isCurrentWeek {
                Button {
                    withAnimation {
                        currentMonday = DateHelpers.mondayOfWeek(containing: Date())
                    }
                } label: {
                    Label("Today", systemImage: "arrow.uturn.left")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        // Calendar dropdown sheet
        .sheet(isPresented: $showCalendar) {
            CalendarDropdown(currentMonday: $currentMonday, isPresented: $showCalendar)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Calendar Dropdown
// ─────────────────────────────────────────────────────────────────────
// Maps to your React calendar <select> dropdown (last 13 weeks).
// In SwiftUI, we present it as a sheet (bottom drawer) — more native
// than a dropdown on iOS.
// ─────────────────────────────────────────────────────────────────────

struct CalendarDropdown: View {
    @Binding var currentMonday: Date
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            List {
                ForEach(DateHelpers.calendarWeeks(), id: \.monday) { week in
                    Button {
                        currentMonday = week.monday
                        isPresented = false
                    } label: {
                        HStack {
                            Text(week.label)
                                .foregroundStyle(.primary)

                            Spacer()

                            if DateHelpers.weekKey(for: week.monday)
                                == DateHelpers.weekKey(for: currentMonday) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(AppTheme.accent)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Week")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { isPresented = false }
                }
            }
        }
    }
}

#Preview {
    WeekNavigator(currentMonday: .constant(DateHelpers.mondayOfWeek(containing: Date())))
}
