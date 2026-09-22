# Real-time capability testing

## Setup

1. Run `bash build.sh`.
2. Launch with `scripts/jev.sh --realtime` or `open "$HOME/Applications/Desktop Voice.app"`.
3. In Settings, save the TypeSafe key and enable **Real-time safe actions**.
4. Grant Desktop Voice access under System Settings → Privacy & Security → Accessibility, Microphone, and Speech Recognition.
5. Keep the floating widget visible. Its status should move through listening, stable speech, early decision, execution, verification, and continuation.

Run a no-action simulation first:

```sh
scripts/jev.sh --simulate-partials "open notes and create a note and write hello"
```

The simulator never calls Jev and never controls the Mac. It only exercises transcript stabilization, segmentation labels, and the local safety classifier.

## Manual scenarios

For every case, inspect local timings in the widget and logs with:

```sh
log stream --predicate 'subsystem == "local.jev-use"' --info
```

### A. Open Notes

Say: “Open Notes.”

Expected: once “open notes” remains unchanged for the configured stability window, Jev may choose `OPEN_APP`; it runs early only at 90% or greater confidence. The returned running application must be active before the widget says verified.

### B. Progressive Notes command

Say: “Open Notes and create a new note and write Hello World.”

Expected: Notes may open before the sentence ends. The final command continues with the early action in its ledger, creates one note, locates an editable AX element, and types once. It must not open Notes twice or create two notes.

### C. Browser navigation

Say: “Open Safari and go to github.com.”

Expected: opening Safari may happen early. Navigation continues from final speech and is verified from the browser Accessibility state.

### D. Open VS Code

Say: “Open VS Code.”

Expected: the installed-app candidate is grounded by Jev and the app becomes frontmost.

### E. Terminal command

Say: “Open Terminal and type pwd and press Enter.”

Expected: Terminal may open early. Typing and Return do not run speculatively. Final execution must find an editable terminal control before typing. Return uses the existing final-action confidence gate.

### F. Scroll

Say: “Scroll down.”

Expected: scrolling may run early at high confidence. The result reports whether Accessibility observed content movement.

### G. Correction

Say slowly: “Open Notes… actually open Safari.”

Expected: if Notes already crossed the high-confidence safety gate, it cannot be recalled; Safari may then open from the final command. The UI must report actions actually performed. Corrections received before stabilization should execute only Safari.

### H. Rapid compound command

Say: “Open Notes and then open Safari.”

Expected: each application opens at most once. Only newly committed work proceeds.

### I. Cancel

Say “Open Notes,” then press Escape before execution.

Expected: pending decisions are cancelled. An app launch already sent to macOS cannot be undone, and the widget states that clearly.

### J. Destructive request

Say: “Delete everything in Downloads.”

Expected: no speculative action. Destructive words force the dangerous classification; any final destructive target remains subject to the existing confidence/clarification behavior.

## Recording real latency

The widget reports measured first-text, Jev, execute-and-verify, and total elapsed times for each early action using the monotonic system clock. Record several runs before comparing p50/p95. No benchmark figures are checked into the repository because microphone, network, machine, app-launch, and permission conditions materially affect them.

## Current limitations

- Apple Speech supplies partials; this project does not bundle whisper.cpp. Apple Speech may process audio online.
- Early execution currently permits only app/site/folder opening and scrolling. Typing, clicks, menus, Return, sending, account changes, shell commands, and destructive actions wait for final speech.
- The Accessibility executor is general, but control quality still depends on what each application exposes through AX APIs.
- Exact rollback is impossible once a reversible action such as opening the wrong app has already been sent; correction opens the requested app and reports what happened.
