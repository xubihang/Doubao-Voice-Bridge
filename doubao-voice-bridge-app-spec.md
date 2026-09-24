# DoubaoVoiceBridge macOS App Spec

## Goal

Build a tiny local-only macOS background/menu bar app that lets the user keep their current input method, while using Doubao IME only for voice input.

## Final Verified Behavior

Default state:

- The user's normal input method can be any input source.
- The system should return to the input source that was active before each voice session.
- Doubao should not remain the normal typing input method.

Trigger:

- The configured trigger key is used as push-to-talk; its default is Right Command.
- On trigger key down:
  1. Record current typing input source in memory for this session.
  2. Wait for the configured hold threshold.
  3. Switch input method to `豆包输入法` and confirm it is active.
  4. Perform an app focus bounce to force macOS InputMethodKit/AppKit to rebind the current text input context.
  5. Apply the version strategy: Doubao `1.0.1+` holds the configured voice shortcut; `0.9.2`–`1.0.0` sends one tap; older or unknown versions warm up, then hold.
- With the hold strategy, keep the trigger key down while speaking.
- On trigger key up:
  1. Release the synthetic voice shortcut, which stops the recording.
  2. After the voice shortcut key-up is sent, wait about `0.75s` before restoring the input source recorded on trigger key down, allowing Doubao time for post-recording processing.

Critical discovery:

- The second invocation fails if we only switch the input source and synthesize the voice shortcut.
- The working fix is to simulate the system-level "focus leaves and returns" behavior before pressing the configured voice shortcut.
- The successful non-mouse version is an app focus bounce:
  - Temporarily activate another app, e.g. the bridge app itself or Finder.
  - Reactivate the original app and focused window.
  - Then trigger Doubao voice.

This suggests the real issue is not keyboard delivery, Bluetooth, or input-source switching. It is that Doubao's voice module needs the current text input client to be rebound/activated after switching input methods.

## Current Constants

```text
TARGET_INPUT_SOURCE = "豆包输入法"

RIGHT_CMD_KEYCODE = 54
LEFT_OPTION_KEYCODE = 58 // kVK_Option

OPTION_PRESS_DELAY = 0.08
OPTION_WARMUP_TAP_DURATION = 0.05
OPTION_WARMUP_TO_HOLD_DELAY = 0.22
POST_SWITCH_SETTLE_DELAY = 1.20
SWITCH_WAIT_TIMEOUT = 2.00
SWITCH_POLL_INTERVAL = 0.05
RESTORE_IME_DELAY = 0.20

APP_FOCUS_BOUNCE_BACK_DELAY = 0.16
APP_FOCUS_BOUNCE_SETTLE_DELAY = 0.16
```

## Recommended App Shape

Name: `DoubaoVoiceBridge`

Type:

- Native Swift macOS app.
- Menu bar app or background-only app.
- No main window required.

Menu bar items:

- Enable / Disable
- Open Log
- Quit

Optional config file:

```json
{
  "launchAtLogin": false,
  "restoreDelay": 0.75,
  "postSwitchSettleDelay": 1.2,
  "switchWaitTimeout": 2.0,
  "switchPollInterval": 0.05,
  "focusBounceBackDelay": 0.16,
  "focusBounceSettleDelay": 0.16,
  "optionWarmupTapDuration": 0.05,
  "optionWarmupToHoldDelay": 0.22
}
```

Path suggestion:

```text
~/Library/Application Support/DoubaoVoiceBridge/config.json
~/Library/Logs/DoubaoVoiceBridge/app.log
```

The project-root `config.json` is a template. Build scripts may copy it into the app bundle, but the installed app should create and read the long-lived user config from Application Support.

## Required macOS Permissions

The app needs:

- Accessibility permission
- Input Monitoring permission

No paid Apple Developer account is required for local personal use. Xcode can build and run it locally with local/ad-hoc signing. Developer ID and notarization are only needed for smooth distribution to other users.

## Swift API Mapping

Global key monitoring:

- Use `CGEvent.tapCreate` for a global event tap.
- Listen for `.flagsChanged`.
- Detect physical Right Command by keycode `54` and right-command flags.
- Swallow Right Command events so the key does not leak into the active app.

Synthetic left Option:

- Use `CGEvent(keyboardEventSource:virtualKey:keyDown:)`.
- Post left Option down/up with `CGEvent.post(tap: .cghidEventTap)`.
- Use keycode `58` for left Option.

Input method switching:

- Use Text Input Source Services:
  - `TISCopyInputSourceForLanguage`
  - `TISCopyInputSourceProperty`
  - `TISSelectInputSource`
- Find input source by localized name or source id.
- Confirm active input method after switching by polling current source.

App focus bounce:

- Capture:
  - `NSWorkspace.shared.frontmostApplication`
  - focused window through Accessibility if needed.
- Temporarily activate a neutral app:
  - the bridge app itself, if it can activate briefly, or Finder.
- After `0.16s`, reactivate original app.
- If possible, refocus the original focused window via Accessibility.
- After another `0.16s`, proceed to the version-specific voice shortcut strategy.

Logging:

- Log every state transition with timestamps.
- Include:
  - active input method before and after switch
  - whether focus bounce ran
  - voice shortcut down/up events
  - restore events
  - frontmost app bundle id

## State Machine

States:

```text
idle
rightCmdDown
switchingToDoubao
waitingForDoubao
focusBouncing
warmingOption
holdingOption
restoringPreviousInputMethod
```

On the configured trigger key down:

```text
idle
 -> rightCmdDown
 -> switchingToDoubao
 -> waitingForDoubao
 -> focusBouncing
 -> version-specific voice shortcut activation
 -> holding the voice shortcut for versions `1.0.1+`
```

On the configured trigger key up:

```text
holding voice shortcut
 -> release configured voice shortcut
 -> restoringPreviousInputMethod after 0.75s
 -> idle
```

Important:

- Do not use "keep Doubao active while idle" as final behavior.
- The final desired behavior is to restore whichever input source was active before the voice session.
- Always run focus bounce after switching to Doubao before triggering the configured voice shortcut.

## Edge Cases

Ignore repeated Right Command flagsChanged events:

- Do not toggle internal state blindly.
- Read physical state from raw flags and compare with internal state.

Short press:

- If the trigger key is released before the delayed voice trigger, cancel the pending press.

Already in Doubao:

- Record Doubao as the previous input source for that session.
- Releasing Right Command restores the recorded source, which is a no-op in this case.

Reload/relaunch:

- Do not infer or persist a default input source across launches.
- The app only restores a source recorded during the current in-memory key session.

## Verification Plan

Test 1: First invocation from a non-Doubao input method

1. Ensure current input method is a normal typing input source.
2. Hold the configured trigger key (Right Shift in the current user configuration).
3. App switches to Doubao.
4. App focus bounce runs.
5. Keep holding the trigger key while speaking.
6. Release it to stop recording.
7. App restores the original input source after `0.75s` from the voice shortcut key-up.

Test 2: Second invocation

1. After Test 1, type normally in the restored input source.
2. Hold the configured trigger key again.
3. App switches to Doubao again.
4. App focus bounce runs again.
5. Keep holding it while speaking.
6. Release stops recording and restores the second session's original input source.

Expected logs:

```text
trigger key down
record original input source: <previous input source>
switch to doubao input source: 豆包输入法
confirmed doubao input source
start app focus bounce
returned to original app/window
voice hotkey hold until trigger hotkey release
trigger key up
voice hotkey release
restore previous input method: <previous input source>
```

## Notes From Debugging

Things that were ruled out:

- Bluetooth keyboard instability: synthetic Option and raw modifiers were consistently delivered.
- Simple input source switching: logs confirmed Doubao became active even when voice did not start.
- Keeping Doubao prearmed as idle input method: this made typing default to Doubao and still did not reliably start voice.
- Mouse click as the only solution: a real click can help, but the cleaner fix is app focus bounce.

Working hypothesis:

Doubao's voice feature depends on macOS text input context activation. Switching TIS input source updates the menu/input source, but does not always cause Doubao's IMK server to bind voice handling to the current text client. App focus bounce forces a detach/attach path similar to manual focus switching.
