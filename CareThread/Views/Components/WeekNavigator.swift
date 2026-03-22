//
//  WeekNavigator.swift
//  CareThread
//
//  Created by Gian Ramirez on 3/18/26.
//

import SwiftUI

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
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentMonday = DateHelpers.offsetWeek(currentMonday, by: -1)
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3.weight(.semibold))
                }

                Spacer()

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
        .sheet(isPresented: $showCalendar) {
            CalendarDropdown(currentMonday: $currentMonday, isPresented: $showCalendar)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }
}

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
