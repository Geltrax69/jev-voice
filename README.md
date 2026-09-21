<p align="center"><img src="docs/banner.png" alt="jev-use" width="100%"></p>

# jev-use

Voice and typed computer use for macOS. You say what you want. Jev picks the next on-screen action. macOS performs it. No screenshots: the app reads the screen through the Accessibility tree.

## Quick start

Requires macOS 14.2+ and Xcode. No dependencies.

```sh
bash build.sh
open "$HOME/Applications/Desktop Voice.app"
```

In setup: save your TypeSafe API key (stored in the Keychain), then allow Accessibility, microphone and speech.

Hold **Control–Option–Space**, speak, release. Change this combination in **Settings → Choose your voice shortcut → Change shortcut**; press the key and any modifiers you want. Your choice is saved across launches. Escape cancels recording, and a conflicting shortcut leaves the previous choice in place. macOS-reserved combinations and modifier-only shortcuts are not supported. **Escape** cancels. Or type a command in the widget, or from a shell: `scripts/say.sh "Open Finder"`.

## Hands-free widget

Click **Start hands-free** in the widget. Speak a command and pause for about 1.5 seconds to submit it. The app waits for Apple's final transcript before acting, pauses its microphone while executing, then listens for your next command. Idle listening sessions renew automatically. Hands-free mode is off at launch.

Click **Hands-free on · Stop**, press **Escape**, close the widget, or open Settings to stop hands-free use. A microphone, recognition, or command error also stops it and shows the problem. Apple Speech may process audio online, as with hold-to-talk.

### Optional wake phrase

Enable **Start hands-free with “Hey Jev”** in Settings, then click **Listen for “Hey Jev”** in the widget. Say “Hey Jev” on its own or followed by a command, such as “Hey Jev, open Finder”. Once activated, hands-free stays on until you stop it; you do not need to repeat the phrase for each command. Stop, Escape, closing the widget, or opening Settings turns all listening off. The preference is saved, but listening never starts automatically at launch.

The phrase must begin the recognized utterance. Unrelated speech is discarded while waiting, without sending commands or screen context to Jev. Wake-word listening uses Apple Speech and may process audio online; it is not a dedicated offline wake-word engine.

## Examples

- "Open Obsidian, create a new note and type hello"
- "Go to youtube.com, search Rick Astley and play the first video"
- "Open 3 new tabs"
- "Scroll down three times"
- "Tile all the Brave windows so none are stacked"
- "In every Brave window, go to wikipedia.org and search for accessibility" — Jev works out the steps once, code repeats them in each window
- "Close the window", "Save", "New tab" — any item in the app's menu bar

## How it works

One loop, about 0.3–1.5 s per step:

1. **Read.** Walk the front app's Accessibility tree (~120 ms). Every element describes itself: what it is, its name, its value, where it sits, what it can do. No per-app code.
2. **Choose.** One request to Jev (`jev-latest`): the goal, the numbered targets, the last ten actions and their effects. Jev selects an operation and a target. It never generates free text; typed text is a span of your sentence.
3. **Act.** Press, select, type, menu, key, scroll, open, arrange windows.
4. **Check.** Read the screen again. Report the real effect. Repeat until DONE, BLOCKED or WAIT.

Low-confidence and destructive picks stop and ask instead of acting.

## What is sent

To `https://api.typesafe.ai/v1/systemone`: your command, the app and window names, the on-screen targets with their labels and values, and recent actions. Secure text fields are excluded. No screenshots. Speech uses Apple Speech.

Everything is logged locally: `log show --predicate 'subsystem == "local.jev-use"' --last 10m --info`

## Develop

```sh
swift test        # requires XCTest from full Xcode
bash scripts/check-desktop.sh  # focused checks; Command Line Tools are sufficient
bash build.sh     # quit the app first
```
