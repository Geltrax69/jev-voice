import Foundation
import JevCore

private func usage() -> Never {
    print("""
    Usage:
      jev-realtime --realtime
      jev-realtime --simulate-partials "open notes and create a note"

    --realtime opens the installed Desktop Voice app. Real-time safe actions are enabled in Settings.
    --simulate-partials runs the stabilizer and safety classifier without controlling the Mac or calling Jev.
    """)
    exit(2)
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard let mode = arguments.first else { usage() }

if mode == "--realtime" {
    let app = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications/Desktop Voice.app")
    guard FileManager.default.fileExists(atPath: app.path) else {
        fputs("Desktop Voice is not installed. Run: bash build.sh\n", stderr)
        exit(1)
    }
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    process.arguments = [app.path]
    try process.run()
    process.waitUntilExit()
    exit(process.terminationStatus)
}

guard mode == "--simulate-partials", arguments.count >= 2 else { usage() }
let command = arguments.dropFirst().joined(separator: " ")
let words = command.split(separator: " ").map(String.init)
var manager = PartialTranscriptManager(configuration: RealtimeConfiguration(stabilityDuration: 0.2, minimumStableUpdates: 2))
var milliseconds = 0

func operation(for text: String) -> (String, String?)? {
    let withoutConnector = text.replacingOccurrences(of: #"\s+(?:and|then)\s*$"#, with: "", options: [.regularExpression, .caseInsensitive])
    let segment = PartialTranscriptManager.segments(in: withoutConnector).last ?? withoutConnector
    let lower = segment.lowercased()
    if lower.hasPrefix("open ") {
        let target = segment.split(separator: " ").dropFirst().joined(separator: " ")
        guard !target.isEmpty else { return nil }
        return target.contains(".") ? ("OPEN_URL", target) : ("OPEN_APP", target)
    }
    if lower == "scroll down" { return ("SCROLL_DOWN", nil) }
    if lower == "scroll up" { return ("SCROLL_UP", nil) }
    if lower.hasPrefix("type ") || lower.hasPrefix("write ") { return ("TYPE_TEXT", nil) }
    if lower.contains("delete") { return ("CLICK", "Delete") }
    return nil
}

for index in words.indices {
    let partial = words[...index].joined(separator: " ")
    milliseconds += 120
    let first = manager.update(partial, at: Double(milliseconds) / 1_000)
    print("[\(milliseconds)ms] \(partial) → \(first.isStable ? "STABLE" : "WAIT")")
    milliseconds += 260
    let stable = manager.update(partial, at: Double(milliseconds) / 1_000)
    guard stable.isStable else { continue }
    if let (action, target) = operation(for: partial) {
        let risk = RealtimeSafetyPolicy.classify(operation: action, target: target, transcript: partial)
        print("[\(milliseconds)ms] stable → candidate \(action)\(target.map { " \($0)" } ?? "") · \(risk.rawValue.uppercased()) · dry-run only")
    } else {
        print("[\(milliseconds)ms] stable → WAIT · no complete deterministic simulation candidate")
    }
}
