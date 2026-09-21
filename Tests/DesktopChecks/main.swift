import AppKit
import Carbon

@main
struct DesktopChecks {
    @MainActor static func main() async throws {
        let name = "local.jev-use.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        precondition(KeyboardShortcut.load(defaults: defaults) == .defaultShortcut)
        func event(_ code: UInt16, _ flags: NSEvent.ModifierFlags, _ text: String) -> NSEvent {
            NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0, context: nil, characters: text, charactersIgnoringModifiers: text, isARepeat: false, keyCode: code)!
        }
        let shortcut = KeyboardShortcut(event: event(40, [.command, .shift], "k"))
        precondition(shortcut.keyCode == 40)
        precondition(shortcut.modifiers == UInt32(cmdKey | shiftKey))
        precondition(shortcut.label == "⇧⌘K")
        shortcut.save(defaults: defaults)
        precondition(KeyboardShortcut.load(defaults: defaults) == shortcut)
        defaults.set(Data("invalid".utf8), forKey: "VoiceShortcut")
        precondition(KeyboardShortcut.load(defaults: defaults) == .defaultShortcut)
        precondition(KeyboardShortcut(event: event(122, [], "")).label == "F1")
        precondition(KeyboardShortcut(event: event(49, [.control, .option], " ")) == .defaultShortcut)
        precondition(KeyboardShortcut(event: event(123, [.command], "")).label == "⌘←")
        let speech = SpeechInput()
        var delivered = false
        speech.onFinal = { _ in delivered = true }
        speech.finish()
        speech.cancel()
        speech.finish()
        precondition(!speech.isListening && !delivered)
        let noSpeech = NSError(domain: "kAFAssistantErrorDomain", code: 1110)
        var restarts = 0
        var failures = 0
        speech.onIdle = { restarts += 1 }
        speech.onFailure = { _ in failures += 1 }
        for _ in 0..<2 {
            speech.handleRecognitionError(noSpeech, handsFree: true)
            try await Task.sleep(nanoseconds: 450_000_000)
        }
        precondition(restarts == 2 && failures == 0 && !delivered)
        speech.handleRecognitionError(noSpeech, handsFree: true)
        speech.cancel()
        try await Task.sleep(nanoseconds: 450_000_000)
        precondition(restarts == 2, "Stop must cancel queued recovery")
        speech.handleRecognitionError(noSpeech, handsFree: false)
        precondition(failures == 1, "Hold-to-talk must still report silence")
        speech.handleRecognitionError(NSError(domain: "Other", code: 1110), handsFree: true)
        precondition(failures == 2)
        speech.handleRecognitionError(NSError(domain: "kAFAssistantErrorDomain", code: 1101), handsFree: true)
        precondition(failures == 3)
        speech.transcript = "unfinished command"
        speech.handleRecognitionError(noSpeech, handsFree: true)
        precondition(failures == 4 && !delivered, "Partial speech must never execute after an error")
        print("Desktop checks passed, including repeated silence recovery, cancellation during recovery, and preservation of real errors.")
    }
}
