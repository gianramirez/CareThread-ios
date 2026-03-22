//
//  ClaudeAPIService.swift
//  CareThread
//
//  Created by Gian Ramirez on 3/18/26.
//

import Foundation
import Observation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
typealias UIImage = NSImage
#endif

enum ClaudeAPIError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse(statusCode: Int)
    case decodingError(String)
    case noContent

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

struct ClaudeResponse: Codable, Sendable {
    let content: [ContentBlock]
}

struct ContentBlock: Codable, Sendable {
    let type: String
    let text: String?
}

struct ClaudeMessage: Codable, Sendable {
    let role: String
    let content: MessageContent

    enum MessageContent: Codable, Sendable {
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

struct MessageBlock: Codable, Sendable {
    let type: String
    let text: String?
    let source: ImageSource?
}

struct ImageSource: Codable, Sendable {
    let type: String
    let mediaType: String
    let data: String

    enum CodingKeys: String, CodingKey {
        case type
        case mediaType = "media_type"
        case data
    }
}

// MARK: - ClaudeAPIService

@Observable
class ClaudeAPIService {
    private var baseURL: String
    private let maxTokens = 1024
    private let model = "claude-sonnet-4-20250514"
    private var debugAPIKey: String?

    var isLoading = false
    var loadingMessage = ""

    init() {
        self.baseURL = AppConfig.apiBaseURL
        self.debugAPIKey = AppConfig.debugAPIKey
    }

    // MARK: - Core API Call

    func callClaude(system: String, messages: [ClaudeMessage]) async throws -> String {
        let (url, headers) = buildRequest()

        var body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "system": system,
        ]

        let encodedMessages = messages.map { msg -> [String: Any] in
            var dict: [String: Any] = ["role": msg.role]
            switch msg.content {
            case .text(let string):
                dict["content"] = string
            case .blocks(let blocks):
                dict["content"] = blocks.map { block -> [String: Any] in
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

        guard let requestURL = url else {
            throw ClaudeAPIError.invalidURL
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeAPIError.networkError(
                NSError(domain: "Invalid response type", code: 0)
            )
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw ClaudeAPIError.invalidResponse(statusCode: httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(ClaudeResponse.self, from: data)

        guard let text = decoded.content.first?.text else {
            throw ClaudeAPIError.noContent
        }

        return text
    }

    // MARK: - High-Level Methods

    func parseDayEntry(text: String) async throws -> ParsedDayData {
        isLoading = true
        loadingMessage = "Reading daycare sheet..."
        defer {
            isLoading = false
            loadingMessage = ""
        }

        let message = ClaudeMessage(role: "user", content: .text(text))
        let responseText = try await callClaude(system: Prompts.dailyParse, messages: [message])

        return try decodeParsedDay(from: responseText)
    }

    func parseDayEntry(image: UIImage) async throws -> ParsedDayData {
        isLoading = true
        loadingMessage = "Analyzing screenshot..."
        defer {
            isLoading = false
            loadingMessage = ""
        }

        #if canImport(UIKit)
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw ClaudeAPIError.decodingError("Could not convert image to JPEG")
        }
        #elseif canImport(AppKit)
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let imageData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
            throw ClaudeAPIError.decodingError("Could not convert image to JPEG")
        }
        #endif
        let base64String = imageData.base64EncodedString()

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

        var fullMessage = ""
        if !routineContext.isEmpty {
            fullMessage += "CHILD'S WEEKLY ROUTINE:\n\(routineContext)\n\n"
        }
        if !therapyContext.isEmpty {
            fullMessage += "THERAPY SCHEDULE:\n\(therapyContext)\n\n"
        }
        fullMessage += "DAILY DATA:\n\(weekData)"

        let message = ClaudeMessage(role: "user", content: .text(fullMessage))

        async let parentReport = callClaude(
            system: Prompts.weeklyReport,
            messages: [message]
        )
        async let careReport = callClaude(
            system: Prompts.careTeamReport,
            messages: [message]
        )

        return try await (parentReport: parentReport, careReport: careReport)
    }

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

    private func buildRequest() -> (URL?, [String: String]) {
        if let apiKey = debugAPIKey, !apiKey.isEmpty {
            let url = URL(string: "https://api.anthropic.com/v1/messages")
            let headers = [
                "Content-Type": "application/json",
                "x-api-key": apiKey,
                "anthropic-version": "2023-06-01",
            ]
            return (url, headers)
        } else {
            let url = URL(string: baseURL)
            let headers = [
                "Content-Type": "application/json"
            ]
            return (url, headers)
        }
    }

    private func decodeParsedDay(from text: String) throws -> ParsedDayData {
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

nonisolated enum AppConfig {
    static let apiBaseURL = "https://your-proxy.workers.dev/api/claude"

    static var debugAPIKey: String? {
        let key = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]
        return (key?.isEmpty ?? true) ? nil : key
    }
}
