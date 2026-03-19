import Foundation
import UIKit  // For UIImage → base64 conversion

// MARK: - ClaudeAPIService
// ─────────────────────────────────────────────────────────────────────
// Translates your React `callClaude(system, messages)` function and
// the Vercel proxy at `/api/claude`.
//
// ARCHITECTURE (Backend Proxy Pattern):
// ┌──────────┐     ┌──────────────────┐     ┌──────────────────┐
// │  iOS App  │────▶│  Your Proxy      │────▶│  Anthropic API   │
// │           │     │  (Cloudflare/    │     │                  │
// │  (no key) │     │   Supabase)      │     │  (key lives here)│
// └──────────┘     └──────────────────┘     └──────────────────┘
//
// WHY: App Store apps can be decompiled. If you ship an API key in
// the binary, anyone can extract it. Your proxy holds the key server-side,
// just like your Vercel function does today.
//
// Java equivalent: This is like a @Service class with a RestTemplate
// (or WebClient) that calls your backend. The async/await pattern in
// Swift maps almost 1:1 to Java's CompletableFuture, but with cleaner
// syntax.
//
// React equivalent: Your `callClaude(system, messages)` fetch() call.
// ─────────────────────────────────────────────────────────────────────

/// Errors that can occur during API calls
enum ClaudeAPIError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse(statusCode: Int)
    case decodingError(String)
    case noContent

    // LocalizedError requires `errorDescription` — like getMessage() in Java exceptions
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL configuration"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse(let code):
            return "Server returned status \(code)"
        case .decodingError(let detail):
            return "Failed to parse response: \(detail)"
        case .noContent:
            return "No content in API response"
        }
    }
}

// MARK: - API Response Types
// These match the JSON structure returned by the Anthropic API.
// In React you just accessed response.content[0].text directly.
// In Swift, we define Codable structs so the JSON decoder can
// type-check everything at compile time.

struct ClaudeResponse: Codable {
    let content: [ContentBlock]
}

struct ContentBlock: Codable {
    let type: String
    let text: String?
}

// MARK: - Message Types (for building requests)

/// A single message in the Claude conversation
struct ClaudeMessage: Codable {
    let role: String
    let content: MessageContent

    /// Content can be a simple string OR an array of content blocks (for images)
    enum MessageContent: Codable {
        case text(String)
        case blocks([MessageBlock])

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .text(let string):
                try container.encode(string)
            case .blocks(let blocks):
                try container.encode(blocks)
            }
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let string = try? container.decode(String.self) {
                self = .text(string)
            } else {
                self = .blocks(try container.decode([MessageBlock].self))
            }
        }
    }
}

/// A content block within a message — either text or an image
struct MessageBlock: Codable {
    let type: String
    let text: String?
    let source: ImageSource?
}

/// Base64-encoded image source for Claude's vision API
struct ImageSource: Codable {
    let type: String  // Always "base64"
    let mediaType: String  // "image/jpeg", "image/png"
    let data: String  // Base64-encoded image data

    enum CodingKeys: String, CodingKey {
        case type
        case mediaType = "media_type"
        case data
    }
}

// MARK: - The Service

/// Main service class for all Claude API interactions.
///
/// Usage:
/// ```swift
/// let service = ClaudeAPIService()
/// let parsed = try await service.parseDayEntry(text: "Today Johnny ate all his lunch...")
/// ```
///
/// @MainActor ensures all published properties update on the main thread
/// (like React's setState — UI updates must happen on the main thread).
@MainActor
class ClaudeAPIService: ObservableObject {
    // ─── Configuration ───────────────────────────────────────────
    // In React, the URL was hardcoded to "/api/claude" (relative to origin).
    // Here we make it configurable so you can point it at your proxy.

    /// The base URL of your backend proxy.
    /// Production: Your Cloudflare Worker or Supabase Edge Function URL
    /// Development: http://localhost:3001/api/claude (your Express server)
    private var baseURL: String

    /// Maximum tokens for Claude responses
    private let maxTokens = 1024

    /// Claude model identifier
    private let model = "claude-sonnet-4-20250514"

    // ─── Debug-only API key ──────────────────────────────────────
    // ⚠️ FOR LOCAL DEVELOPMENT ONLY — NEVER SHIP THIS IN PRODUCTION
    // Set via: Edit Scheme → Run → Environment Variables → ANTHROPIC_API_KEY
    //
    // When set, the service calls Anthropic directly (bypassing proxy).
    // When nil, it calls your proxy (production behavior).
    private var debugAPIKey: String?

    // ─── Published state for UI binding ──────────────────────────
    // @Published is SwiftUI's version of React's useState.
    // Any View observing this service will re-render when these change.
    @Published var isLoading = false
    @Published var loadingMessage = ""

    // MARK: - Initialization

    init(
        baseURL: String = AppConfig.apiBaseURL,
        debugAPIKey: String? = AppConfig.debugAPIKey
    ) {
        self.baseURL = baseURL
        self.debugAPIKey = debugAPIKey
    }

    // MARK: - Core API Call

    /// The core method — equivalent to your React `callClaude(system, messages)`.
    ///
    /// `async throws` is Swift's version of returning a Promise that can reject.
    /// - In Java: `CompletableFuture<String>` that can throw
    /// - In React: `async function callClaude()` with try/catch
    ///
    /// The `await` keyword at call sites is like JS's `await` — it suspends
    /// execution until the network call completes, but does NOT block the UI thread.
    func callClaude(system: String, messages: [ClaudeMessage]) async throws -> String {
        // Determine if we're calling the proxy or Anthropic directly
        let (url, headers) = try buildRequest()

        // Build the request body — matches your React fetch() body
        var body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "system": system,
        ]

        // Encode messages manually (because MessageContent is an enum)
        let encodedMessages = try messages.map { msg -> [String: Any] in
            var dict: [String: Any] = ["role": msg.role]
            switch msg.content {
            case .text(let string):
                dict["content"] = string
            case .blocks(let blocks):
                dict["content"] = try blocks.map { block -> [String: Any] in
                    var blockDict: [String: Any] = ["type": block.type]
                    if let text = block.text { blockDict["text"] = text }
                    if let source = block.source {
                        blockDict["source"] = [
                            "type": source.type,
                            "media_type": source.mediaType,
                            "data": source.data,
                        ]
                    }
                    return blockDict
                }
            }
            return dict
        }
        body["messages"] = encodedMessages

        // Create the URLRequest — like building a fetch() Request in JS
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60  // 60 second timeout
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Make the network call — this is the `await fetch()` equivalent
        let (data, response) = try await URLSession.shared.data(for: request)

        // Check HTTP status — like checking response.ok in fetch()
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeAPIError.networkError(
                NSError(domain: "Invalid response type", code: 0)
            )
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            // Try to get error details from response body
            if let errorText = String(data: data, encoding: .utf8) {
                print("API Error (\(httpResponse.statusCode)): \(errorText)")
            }
            throw ClaudeAPIError.invalidResponse(statusCode: httpResponse.statusCode)
        }

        // Decode the response — like JSON.parse() in JS
        let decoded = try JSONDecoder().decode(ClaudeResponse.self, from: data)

        guard let text = decoded.content.first?.text else {
            throw ClaudeAPIError.noContent
        }

        return text
    }

    // MARK: - High-Level Methods

    /// Parse a daycare daily sheet from text.
    /// React equivalent: parseEntry() when inputMode === "text"
    func parseDayEntry(text: String) async throws -> ParsedDayData {
        isLoading = true
        loadingMessage = "Reading daycare sheet..."
        defer {
            // `defer` runs when the scope exits — like Java's finally block.
            // Ensures we always stop the loading state, even if an error is thrown.
            isLoading = false
            loadingMessage = ""
        }

        let message = ClaudeMessage(role: "user", content: .text(text))
        let responseText = try await callClaude(system: Prompts.dailyParse, messages: [message])

        return try decodeParsedDay(from: responseText)
    }

    /// Parse a daycare daily sheet from a screenshot image.
    /// React equivalent: parseEntry() when inputMode === "image"
    func parseDayEntry(image: UIImage) async throws -> ParsedDayData {
        isLoading = true
        loadingMessage = "Analyzing screenshot..."
        defer {
            isLoading = false
            loadingMessage = ""
        }

        // Convert UIImage to base64 — like FileReader.readAsDataURL() in JS
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw ClaudeAPIError.decodingError("Could not convert image to JPEG")
        }
        let base64String = imageData.base64EncodedString()

        // Build a multi-block message with image + text (Claude vision API)
        let blocks: [MessageBlock] = [
            MessageBlock(
                type: "image",
                text: nil,
                source: ImageSource(type: "base64", mediaType: "image/jpeg", data: base64String)
            ),
            MessageBlock(
                type: "text",
                text: "Please analyze this daycare daily sheet.",
                source: nil
            ),
        ]
        let message = ClaudeMessage(role: "user", content: .blocks(blocks))
        let responseText = try await callClaude(system: Prompts.dailyParse, messages: [message])

        return try decodeParsedDay(from: responseText)
    }

    /// Generate weekly reports (parent + care team) — runs BOTH in parallel.
    /// React equivalent: generateReport() with Promise.all([parent, careTeam])
    ///
    /// `async let` is Swift's version of starting parallel async operations.
    /// It's like calling two fetch()s and then Promise.all()-ing them.
    func generateWeeklyReports(
        weekData: String,
        routineContext: String,
        therapyContext: String
    ) async throws -> (parentReport: String, careReport: String) {
        isLoading = true
        loadingMessage = "Generating weekly reports..."
        defer {
            isLoading = false
            loadingMessage = ""
        }

        // Build the full context message (same format as your React app)
        var fullMessage = ""
        if !routineContext.isEmpty {
            fullMessage += "CHILD'S WEEKLY ROUTINE:\n\(routineContext)\n\n"
        }
        if !therapyContext.isEmpty {
            fullMessage += "THERAPY SCHEDULE:\n\(therapyContext)\n\n"
        }
        fullMessage += "DAILY DATA:\n\(weekData)"

        let message = ClaudeMessage(role: "user", content: .text(fullMessage))

        // Fire both API calls in parallel — this is the Swift equivalent of:
        //   const [parent, care] = await Promise.all([...])
        async let parentReport = callClaude(
            system: Prompts.weeklyReport,
            messages: [message]
        )
        async let careReport = callClaude(
            system: Prompts.careTeamReport,
            messages: [message]
        )

        // Await both results — if either fails, the error propagates
        return try await (parentReport: parentReport, careReport: careReport)
    }

    /// Generate monthly report from weekly reports.
    /// React equivalent: generateMonthlyReport()
    func generateMonthlyReport(
        weeklyReports: String,
        therapyContext: String
    ) async throws -> String {
        isLoading = true
        loadingMessage = "Generating monthly report..."
        defer {
            isLoading = false
            loadingMessage = ""
        }

        var fullMessage = ""
        if !therapyContext.isEmpty {
            fullMessage += "THERAPY SCHEDULE:\n\(therapyContext)\n\n"
        }
        fullMessage += "WEEKLY REPORTS:\n\(weeklyReports)"

        let message = ClaudeMessage(role: "user", content: .text(fullMessage))
        return try await callClaude(system: Prompts.monthlyReport, messages: [message])
    }

    // MARK: - Private Helpers

    /// Determine the URL and headers based on whether we're in debug or production mode.
    private func buildRequest() throws -> (URL, [String: String]) {
        if let apiKey = debugAPIKey, !apiKey.isEmpty {
            // ⚠️ DEBUG MODE: Calling Anthropic directly
            // This bypasses your proxy — only for local testing!
            guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
                throw ClaudeAPIError.invalidURL
            }
            let headers = [
                "Content-Type": "application/json",
                "x-api-key": apiKey,
                "anthropic-version": "2023-06-01",
            ]
            return (url, headers)
        } else {
            // 🔒 PRODUCTION MODE: Calling your backend proxy
            // The proxy adds the API key server-side
            guard let url = URL(string: baseURL) else {
                throw ClaudeAPIError.invalidURL
            }
            let headers = [
                "Content-Type": "application/json"
            ]
            return (url, headers)
        }
    }

    /// Parse Claude's JSON response into our ParsedDayData struct.
    /// In React you did JSON.parse(responseText).
    /// Swift's JSONDecoder is like Jackson's ObjectMapper in Spring Boot.
    private func decodeParsedDay(from text: String) throws -> ParsedDayData {
        // Claude sometimes wraps JSON in markdown code fences — strip them
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8) else {
            throw ClaudeAPIError.decodingError("Could not convert response to data")
        }

        do {
            return try JSONDecoder().decode(ParsedDayData.self, from: data)
        } catch {
            throw ClaudeAPIError.decodingError(error.localizedDescription)
        }
    }
}

// MARK: - App Configuration
// ─────────────────────────────────────────────────────────────────────
// Centralized config — like application.properties in Spring Boot.
//
// In production, only `apiBaseURL` is used (points to your proxy).
// The `debugAPIKey` is ONLY populated from Xcode's environment variables
// during development.
// ─────────────────────────────────────────────────────────────────────

enum AppConfig {
    /// Your backend proxy URL.
    /// Replace with your Cloudflare Worker or Supabase Edge Function URL.
    /// During local dev, you can point this at your Express server.
    static let apiBaseURL = "https://your-proxy.workers.dev/api/claude"

    /// Debug API key — reads from Xcode environment variable.
    /// Set via: Product → Scheme → Edit Scheme → Run → Environment Variables
    /// Add: ANTHROPIC_API_KEY = sk-ant-...
    ///
    /// ⚠️ This is NEVER included in the compiled app binary.
    /// ProcessInfo.processInfo.environment only works in the Xcode debugger.
    static var debugAPIKey: String? {
        let key = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]
        return (key?.isEmpty ?? true) ? nil : key
    }
}
