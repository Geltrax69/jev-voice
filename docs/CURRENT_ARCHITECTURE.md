# Current architecture

Baseline audited on 2026-09-22 at upstream commit `b22e568`.

## Runtime pipeline

```text
hot key / hands-free / wake phrase / typed notification
                        |
                        v
             SpeechInput (Apple Speech)
             partial UI transcript only
                        |
                 final transcript
                        v
        AppModel.run(command, frontmost app)
              /                    \
  optional OpenRouter planner       Jev cycle loop
      typed PlanStep list       operation + grounded target
              \                    /
                        v
          Desktop Accessibility snapshot
                        |
          semantic action / key event / URL
                        |
          fresh Accessibility observation
                        |
             verify effect and continue
```

## Activation and audio

- `HotKey.swift` registers the configurable global shortcut. Press starts recognition and release requests finalization.
- `JevDesktopApp.swift` owns hold-to-talk, hands-free, wake-phrase, typed-command, overlay, cancellation, command queuing, and execution state.
- `SpeechInput.swift` captures microphone buffers with `AVAudioEngine` and passes them to `SFSpeechAudioBufferRecognitionRequest`.
- Apple Speech is configured with `shouldReportPartialResults = true`. Partial text currently updates the widget, but only `result.isFinal` reaches `AppModel.run`.
- Hands-free endpointing is a 1.5 second timer restarted by each changed partial. Hold-to-talk ends when the shortcut is released. Apple may also produce its own final result.
- Speech and microphone permissions are requested in `SpeechInput`; Accessibility permission is requested by `Desktop`.
- The implementation is Apple Speech, not whisper.cpp. Recognition may use Apple online processing, as documented by the UI and README.

## Decisions and compound commands

- `JevCore/Decision.swift` sends a closed choice set to `jev-latest`. The default execution loop asks for one operation and any relevant target in each cycle.
- `JevCore/Planner.swift` is an optional OpenRouter planner. It converts a complete utterance into typed `PlanStep` values, after which deterministic actions run directly and screen-dependent targets are grounded by Jev.
- Compound requests are not split with a simple delimiter. The planner produces ordered steps when enabled; otherwise the cycle loop repeatedly observes, chooses one next action, executes, and re-observes until `DONE`, `BLOCKED`, or `WAIT`.
- Recent action results are included in later decisions, which suppresses repetition within a completed final-command cycle. There is no utterance-scoped ledger for overlapping partial transcripts yet.

## macOS observation and execution

- `Desktop.swift` is the Accessibility layer. It reads `AXUIElement` roles, subroles, labels, descriptions, values, enabled/hidden state, children, windows, menu items, actions, positions, and settable attributes.
- Accessibility traversal filters and ranks meaningful controls and builds compact `Candidate` and `Element` descriptions. Secure text fields are excluded.
- Application discovery uses running applications plus installed applications under standard system and user Applications directories whose names match command words.
- Actions prefer semantic AX operations (`AXPress`, selection, focus and value/selected-text mutation). Keyboard, scroll, URL opening, Apple events and coordinate clicks are fallbacks where required.
- Typing candidates are created only for writable/editable Accessibility elements. `Desktop.perform` focuses the target and verifies mutations where the AX value can be read.
- Each cycle fingerprints or captures the current UI after an action. App/window changes and element values provide observed results; action results are returned as concrete strings rather than assumed success.

## UI and feedback

- `JevDesktopApp.swift` implements the menu-bar app, settings, floating voice widget, pixel-word visualization, permission state, status text, action progress and coarse timing.
- `SystemAudio.swift` monitors output audio so the speech UX can react to system playback.
- Logging uses subsystem `local.jev-use`; no screenshots are captured or uploaded.

## Real-time gaps

The repository already has partial recognition and a strong semantic Accessibility executor. The missing real-time layer is between them:

1. stabilize partial transcripts across updates and time;
2. segment only newly committed command spans;
3. classify every typed action by speculative safety;
4. require a higher confidence for partial decisions than final decisions;
5. keep an utterance-scoped executed-action ledger;
6. route eligible stable partials into execution while recognition continues;
7. reconcile the final transcript without replaying committed actions;
8. record monotonic STT, stability, decision, execution and verification latency;
9. expose real-time status and a deterministic partial-simulation test path.

## Baseline verification

The following completed successfully before functional changes:

- `swift test`: 10 tests passed.
- `bash build.sh`: release app built, signed and installed at `~/Applications/Desktop Voice.app`.
- `bash scripts/check-desktop.sh`: focused speech recovery and cancellation checks passed.

Baseline warnings exist for Swift sendability in `Desktop.capture`, two unreachable `typingOnly` branches, a Core Audio `CFString` pointer, and the macOS 27 deprecation of the current audio tap API. They do not fail the build and are unrelated to the real-time behavior.

## Files expected to change

- `Sources/JevCore/`: partial transcript stabilization, segmentation, safety policy, action identity/ledger, latency data and tests.
- `Sources/JevDesktop/SpeechInput.swift`: publish timestamped partial/final events without changing microphone capture.
- `Sources/JevDesktop/JevDesktopApp.swift`: real-time session coordination, partial decisions, progressive execution, final reconciliation and overlay status.
- `Sources/JevDesktop/Desktop.swift`: expose compact verification results where the current internal strings are insufficient.
- `Tests/JevCoreTests/`: deterministic stability, safety, duplication and progressive-command tests.
- `README.md` and `TESTING_REALTIME.md`: configuration, privacy, limitations and manual acceptance tests.
