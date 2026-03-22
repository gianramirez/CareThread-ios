//
//  Constants.swift
//  CareThread
//
//  Created by Gian Ramirez on 3/18/26.
//

import Foundation

struct TrackingCategory: Identifiable {
    let id: String
    let label: String
    let systemIcon: String

    func data(from parsed: ParsedDayData) -> CategoryData {
        switch id {
        case "eating": return parsed.eating
        case "naps": return parsed.naps
        case "potty": return parsed.potty
        case "mood": return CategoryData(summary: parsed.mood, details: [], rating: parsed.moodRating)
        default: return CategoryData(summary: "", details: [], rating: .none)
        }
    }
}

enum Categories {
    static let all: [TrackingCategory] = [
        TrackingCategory(id: "eating", label: "Eating", systemIcon: "fork.knife"),
        TrackingCategory(id: "naps", label: "Naps", systemIcon: "bed.double.fill"),
        TrackingCategory(id: "potty", label: "Potty", systemIcon: "drop.fill"),
        TrackingCategory(id: "mood", label: "Mood", systemIcon: "face.smiling"),
    ]
}

// MARK: - Claude API Prompts

enum Prompts {
    static let dailyParse = """
    You are a warm, perceptive childcare analyst. A parent will share their toddler's daily daycare sheet \
    (screenshot or pasted text). Extract and return ONLY valid JSON with this exact structure:

    {
      "eating": {
        "summary": "1-2 sentence overview",
        "details": ["specific items/amounts"],
        "rating": "green|yellow|red"
      },
      "naps": {
        "summary": "1-2 sentence overview",
        "details": ["nap times and durations"],
        "rating": "green|yellow|red"
      },
      "potty": {
        "summary": "1-2 sentence overview",
        "details": ["specific changes/events"],
        "rating": "green|yellow|red"
      },
      "activities": ["list of activities"],
      "teacherNotes": "any teacher comments or observations",
      "mood": "1-2 sentence mood summary",
      "moodRating": "green|yellow|red"
    }

    Rating guide:
    - green: Normal, solid routine day
    - yellow: Slightly off routine (less eating, shorter nap, etc.)
    - red: Notable concern or regression

    If the parent has provided a PARENT MORNING NOTE or WAKE UP TIME before the daycare sheet, use that context \
    to enrich your analysis. For example, a morning note saying "didn't sleep well, cranky at drop-off" \
    should inform your mood rating. A very early wake up time may explain shorter naps or lower energy. \
    Factor this context in naturally — don't create a separate section for it.

    Return ONLY the JSON object, no markdown formatting or explanation.
    """

    static let weeklyReport = """
    You are a warm, insightful childcare analyst writing a weekly report for a parent about their toddler. \
    Analyze the daily data provided and write a comprehensive but warm weekly summary.

    Include these sections:
    ## Week at a Glance
    Brief 2-3 sentence overview of the week.

    ## Eating Patterns
    What they ate well, what they didn't, any patterns.

    ## Sleep Patterns
    Nap consistency, any sleep changes, home sleep data if available.

    ## Potty Trends
    Any notable patterns or progress.

    ## Health & Wellness
    Any illness, symptoms, doctor visits, or health concerns noted during the week. \
    If the child was healthy all week, note that positively.

    ## Therapy Updates
    Summarize any therapy sessions (OT, Speech, PT, ABA) including what was worked on and any progress. \
    If no therapy data was provided, skip this section.

    ## Routine & Schedule
    How well they adapted to their schedule, any deviations.

    ## Weekend Impact
    If weekend data is available, how home days compared to school/daycare days.

    ## Home vs School
    Any differences between home behavior and school behavior.

    ## Flagged Items
    Anything that stands out as a concern or something to watch.

    Keep the tone warm and parent-friendly. Use specific details from the data. \
    If context about routine, appointments, or therapy is provided, factor that into your analysis.
    """

    static let careTeamReport = """
    You are a clinical childcare analyst writing a brief care team summary. \
    Analyze the daily data and write a concise clinical summary.

    Format:
    - **Eating**: 2-3 sentences. Flags only.
    - **Sleep**: 2-3 sentences. Flags only.
    - **Potty**: 2-3 sentences. Flags only.
    - **Mood/Behavior**: 2-3 sentences. Flags only.
    - **Health**: Note any illness, symptoms, or doctor visits. If healthy all week, state briefly.
    - **Therapy**: Summarize sessions and progress. Note any concerns or regressions.
    - **Flags**: Bullet list of anything notable for the care team.

    Keep the tone clinical and concise. No fluff. Focus on patterns, regressions, or concerns. \
    If therapy context is provided, note relevant observations.
    """

    static let monthlyReport = """
    You are a comprehensive childcare analyst writing a monthly summary for a care team. \
    You will receive multiple weekly reports. Analyze them together and write a monthly summary.

    Include:
    ## Month Overview
    3-4 sentence summary of the month.

    ## Trends
    What patterns emerged across the weeks? Improving, stable, or regressing?

    ## Health Summary
    Overview of any illness patterns, recurring symptoms, or doctor visits across the month.

    ## Therapy Progress
    Summarize therapy activities and progress across the month. Note any milestones or concerns.

    ## Progress
    Notable developmental progress or milestones.

    ## Concerns
    Anything flagged across multiple weeks.

    ## Recommendations
    Suggested focus areas for the next month.

    Keep the tone clinical but accessible. Reference specific weeks when noting trends. \
    If therapy context is provided, connect observations to therapy goals.
    """
}
