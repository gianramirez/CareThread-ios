import SwiftUI
import SwiftData

// MARK: - CareThreadApp
// ─────────────────────────────────────────────────────────────────────
// The app entry point — like main() in Java or ReactDOM.render() in React.
//
// In Swift, @main marks the entry point. The App protocol is the
// top-level container for a SwiftUI app.
//
// KEY CONCEPT — @main + App protocol:
// In Java: public static void main(String[] args)
// In React: ReactDOM.createRoot(document.getElementById('root')).render(<App />)
// In SwiftUI: @main struct MyApp: App { var body: some Scene { ... } }
//
// The Scene → WindowGroup → ContentView chain is:
//   App → creates a window → fills it with your root view
// It's like Spring Boot's @SpringBootApplication — one annotation
// bootstraps the entire application.
//
// SwiftData Setup:
// .modelContainer() is where we register our data models.
// Think of it as Spring Boot's @EntityScan + JPA auto-configuration.
// It creates the SQLite database, generates the schema from our @Model
// classes, and makes ModelContext available via @Environment.
// ─────────────────────────────────────────────────────────────────────

@main
struct CareThreadApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        // Register all SwiftData models — like JPA entity scanning
        // The `for:` parameter lists every @Model class in your app
        .modelContainer(for: [
            WeekEntry.self,
            AppSettings.self,
            MonthlyReport.self,
        ])
    }
}
