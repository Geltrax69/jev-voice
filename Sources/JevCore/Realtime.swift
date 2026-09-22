import Foundation

public struct RealtimeConfiguration: Equatable, Sendable {
    public var enabled: Bool
    public var partialInterval: TimeInterval
    public var stabilityDuration: TimeInterval
    public var minimumStableUpdates: Int
    public var speculativeConfidence: Double
    public var finalConfidence: Double
    public var decisionCooldown: TimeInterval

    public init(enabled: Bool = true, partialInterval: TimeInterval = 0.2, stabilityDuration: TimeInterval = 0.25,
                minimumStableUpdates: Int = 2, speculativeConfidence: Double = 0.9,
                finalConfidence: Double = 0.5, decisionCooldown: TimeInterval = 0.2) {
        self.enabled = enabled
        self.partialInterval = max(0.05, partialInterval)
        self.stabilityDuration = max(0, stabilityDuration)
        self.minimumStableUpdates = max(2, minimumStableUpdates)
        self.speculativeConfidence = min(1, max(0, speculativeConfidence))
        self.finalConfidence = min(1, max(0, finalConfidence))
        self.decisionCooldown = max(0, decisionCooldown)
    }

    public static func environment(_ values: [String: String] = ProcessInfo.processInfo.environment) -> Self {
        func bool(_ name: String, _ fallback: Bool) -> Bool {
            guard let value = values[name]?.lowercased() else { return fallback }
            return !["0", "false", "no", "off"].contains(value)
        }
        func seconds(_ name: String, _ fallback: Double) -> Double {
            values[name].flatMap(Double.init).map { $0 / 1_000 } ?? fallback
        }
        let defaults = Self()
        return Self(enabled: bool("REALTIME_MODE", defaults.enabled),
                    partialInterval: seconds("PARTIAL_INTERVAL_MS", defaults.partialInterval),
                    stabilityDuration: seconds("PARTIAL_STABILITY_MS", defaults.stabilityDuration),
                    minimumStableUpdates: values["PARTIAL_MIN_STABLE_UPDATES"].flatMap(Int.init) ?? defaults.minimumStableUpdates,
                    speculativeConfidence: values["SPECULATIVE_ACTION_CONFIDENCE"].flatMap(Double.init) ?? defaults.speculativeConfidence,
                    finalConfidence: values["FINAL_ACTION_CONFIDENCE"].flatMap(Double.init) ?? defaults.finalConfidence,
                    decisionCooldown: seconds("PARTIAL_JEV_COOLDOWN_MS", defaults.decisionCooldown))
    }
}

public struct PartialTranscriptUpdate: Equatable, Sendable {
    public let transcript: String
    public let stableTranscript: String?
    public let stableUpdates: Int
    public let isFinal: Bool

    public var isStable: Bool { stableTranscript != nil }
}

/// Turns noisy speech-recognition revisions into deliberately conservative stable text.
public struct PartialTranscriptManager: Sendable {
    public let configuration: RealtimeConfiguration
    private var previous = ""
    private var candidate = ""
    private var candidateSince: TimeInterval = 0
    private var candidateUpdates = 0
    private var lastDecisionAt = -Double.infinity
    public private(set) var lastStableTranscript = ""

    public init(configuration: RealtimeConfiguration = .init()) { self.configuration = configuration }

    public mutating func reset() { self = Self(configuration: configuration) }

    public mutating func update(_ raw: String, at timestamp: TimeInterval, isFinal: Bool = false) -> PartialTranscriptUpdate {
        let text = Self.normalized(raw)
        guard !text.isEmpty else {
            previous = ""
            candidate = ""
            candidateUpdates = 0
            return PartialTranscriptUpdate(transcript: "", stableTranscript: nil, stableUpdates: 0, isFinal: isFinal)
        }
        if isFinal {
            previous = text
            candidate = text
            candidateUpdates = max(candidateUpdates, configuration.minimumStableUpdates)
            lastStableTranscript = text
            return PartialTranscriptUpdate(transcript: text, stableTranscript: text, stableUpdates: candidateUpdates, isFinal: true)
        }

        if text == previous {
            candidateUpdates += 1
        } else {
            candidate = text
            candidateSince = timestamp
            candidateUpdates = 1
        }
        previous = text
        let oldEnough = timestamp - candidateSince >= configuration.stabilityDuration
        let enoughUpdates = candidateUpdates >= configuration.minimumStableUpdates
        let stable = oldEnough && enoughUpdates && !candidate.isEmpty ? candidate : nil
        if let stable { lastStableTranscript = stable }
        return PartialTranscriptUpdate(transcript: text, stableTranscript: stable, stableUpdates: candidateUpdates, isFinal: false)
    }

    public mutating func mayDecide(at timestamp: TimeInterval) -> Bool {
        guard timestamp - lastDecisionAt >= configuration.decisionCooldown else { return false }
        lastDecisionAt = timestamp
        return true
    }

    public static func segments(in transcript: String) -> [String] {
        normalized(transcript)
            .replacingOccurrences(of: #"\s+(?:and then|and|then)\s+"#, with: "\n", options: [.regularExpression, .caseInsensitive])
            .components(separatedBy: CharacterSet(charactersIn: "\n;,"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func normalized(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

}

public enum ActionRisk: String, Codable, Sendable { case safe, caution, dangerous }

public enum RealtimeSafetyPolicy {
    private static let dangerousWords = ["delete", "remove", "trash", "empty trash", "erase", "purchase", "buy", "pay", "send", "email", "message", "password", "sudo", "git push", "account", "discard"]

    public static func classify(operation: String, target: String? = nil, transcript: String = "") -> ActionRisk {
        let words = [operation, target ?? "", transcript].joined(separator: " ").lowercased()
        if dangerousWords.contains(where: words.contains) || operation == "QUIT_APP" { return .dangerous }
        switch operation {
        case "OPEN_APP", "OPEN_URL", "OPEN_FOLDER", "SCROLL_DOWN", "SCROLL_UP", "NEXT_TAB", "GO_BACK", "FOCUS_INPUT": return .safe
        case "TYPE_TEXT", "PRESS_RETURN", "MENU", "CLICK", "PRESS_ESCAPE", "SKIP_FORWARD", "SKIP_BACK", "ARRANGE_WINDOWS": return .caution
        default: return .caution
        }
    }

    public static func allowsSpeculation(operation: String, target: String? = nil, transcript: String,
                                         confidence: Double, configuration: RealtimeConfiguration = .init()) -> Bool {
        classify(operation: operation, target: target, transcript: transcript) == .safe && confidence >= configuration.speculativeConfidence
    }
}

public struct ExecutedAction: Equatable, Sendable {
    public let id: String
    public let transcriptSpan: String
    public let timestamp: TimeInterval
    public let result: String

    public init(id: String, transcriptSpan: String, timestamp: TimeInterval, result: String) {
        self.id = id; self.transcriptSpan = transcriptSpan; self.timestamp = timestamp; self.result = result
    }
}

public struct ExecutedActionLedger: Sendable {
    public private(set) var actions: [ExecutedAction] = []
    public init() {}

    public func contains(_ id: String) -> Bool { actions.contains { $0.id == id } }
    public mutating func record(id: String, transcriptSpan: String, timestamp: TimeInterval, result: String) -> Bool {
        guard !contains(id) else { return false }
        actions.append(ExecutedAction(id: id, transcriptSpan: transcriptSpan, timestamp: timestamp, result: result))
        return true
    }
    public mutating func reset() { actions.removeAll(keepingCapacity: true) }

    public static func identity(operation: String, target: String?) -> String {
        let normalized = (target ?? "").lowercased().split { !$0.isLetter && !$0.isNumber }.joined(separator: "-")
        return "\(operation.uppercased()):\(normalized)"
    }
}

public struct LatencySample: Equatable, Sendable {
    public let stt, stability, decision, execution, verification, total: TimeInterval
    public init(stt: TimeInterval = 0, stability: TimeInterval = 0, decision: TimeInterval = 0,
                execution: TimeInterval = 0, verification: TimeInterval = 0, total: TimeInterval = 0) {
        self.stt = stt; self.stability = stability; self.decision = decision
        self.execution = execution; self.verification = verification; self.total = total
    }
}

public struct LatencySummary: Equatable, Sendable {
    public let minimum, p50, p95, maximum: TimeInterval
}

public enum LatencyStatistics {
    public static func summarize(_ values: [TimeInterval]) -> LatencySummary? {
        let sorted = values.sorted()
        guard let first = sorted.first, let last = sorted.last else { return nil }
        func percentile(_ value: Double) -> Double {
            sorted[Int((Double(sorted.count - 1) * value).rounded(.up)).clamped(to: 0...(sorted.count - 1))]
        }
        return LatencySummary(minimum: first, p50: percentile(0.5), p95: percentile(0.95), maximum: last)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self { min(max(self, range.lowerBound), range.upperBound) }
}
