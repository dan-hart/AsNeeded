---
name: sim-use
description: Use when researching or reproducing mobile app behavior, verifying flows on iOS Simulator or Android emulator/devices, or capturing mobile UI evidence with the sim-use CLI.
---

# sim-use

Use the CLI for mobile observation and interaction. Keep desktop/browser research in the existing web and computer-use tools. Read [the tool guide](references/device-verification.md) for AsNeeded setup, platform limits, and evidence requirements. This is a repository-maintained adaptation; consult installed help when upstream documentation differs.

## Select and inspect the target

```bash
command -v sim-use
sim-use --version
sim-use devices
sim-use ui --device '<device-id>'
```

Confirm the intended platform, device kind, runtime, and foreground app. Pass `--device` explicitly throughout the task; never choose a different booted device silently. If the binary is missing, use another available device-verification tool or report the gap. Installation and device setup need task authorization. Do not run `sim-use init`; this repo carries portable instructions without requiring discovery symlinks.

For a connected Android target, `sim-use android init --device '<serial>'` installs the bridge APK. This is device setup, not a read-only probe; establish authorization before installing or accepting new permissions. macOS supports both mobile backends; upstream's Linux build is Android-only, with a smaller command set. Check local help rather than assuming parity.

## Observe, act, verify

Choose a target from the latest `ui` output, act once, and read the resulting state. A successful tap command only confirms dispatch. Verify a meaningful state such as the destination heading and expected field, selected tab, or exact entered text. Use that verification read as the next observation.

| Selector | Use |
| --- | --- |
| `tap @N` | Fast cached alias from the most recent observation |
| `tap '#<identifier>'` | Stable identifier actually present in the outline |
| `tap --label 'Text' --element-type Button` | Label selection with collision disambiguation |
| `tap --point x,y` | Last resort, grounded in a fresh screenshot or outline geometry |

Refresh `ui` after navigation, scrolls, dialogs, rotation, or other screen changes before reusing aliases. Never assume `@9` still identifies the same control. For missing/duplicate labels, inspect the new outline and use a real identifier, type, or frame filter. Bound waits and retries; inspect `--json` error hints rather than blindly repeating actions.

Example for a simulator already on Settings > General; these labels must be present before use:

```bash
sim-use ui --device '<simulator-udid>'
sim-use tap --label 'About' --element-type Button --device '<simulator-udid>'
sim-use ui --device '<simulator-udid>'
# Verify the About heading and iOS Version field; confirm #BackButton is present.
sim-use tap '#BackButton' --device '<simulator-udid>'
sim-use ui --device '<simulator-udid>'
```

## Mobile checks

- Use `gesture scroll-up` to move content upward and reveal items farther down the page. Observe again after scrolling.
- Use `type` for simple text; prefer `paste` for Unicode/IME-sensitive input after focusing the field. Check the exact result. Paste can affect shared clipboards; avoid competing clipboard writers and inspect ambiguous results before retrying.
- Use screenshots for layout, images, colors, clipping, or visual parity. An accessibility outline cannot establish visual correctness. Inspect screenshots before claiming a visual result.
- Use `record-video` only for relevant, sanitized evidence; stop recordings gracefully with SIGINT/SIGTERM so they finalize. Check installed help for gesture, rotation, folding, and recording options before using unfamiliar forms.
- Prefer the text outline for ordinary checks. For structured observations use `ui --json --no-raw` to omit the large raw tree. Verify coordinates and units for the selected platform; do not reuse desktop screenshot pixels as iOS points.

## Physical iPhones and iPads

Physical-iOS support is experimental. `ui` and selector-based `tap` require a paired, trusted, unlocked device in Developer Mode and a foreground app signed for development with `get-task-allow=true`. TestFlight, App Store, distribution-signed, and system apps do not support this inspection/tap path. Screenshots have broader coverage.

The physical-iOS surface supports `ui`, stable-ID/label `tap`, and `screenshot`. Do not try cached aliases, coordinate taps, swipe/multitouch, type/paste, or recording as if it were a simulator. A capability rejection is not a transient error. Explain the limit and select an authorized alternative; do not repeatedly retry an unsupported app or input channel.

## Report evidence accurately

State device/runtime, app build, tested steps, assertions, failures, and untested areas. Keep screenshots and UI dumps containing private data out of commits. Follow the task's existing authorization for account actions or submissions.

For benchmarks, compare identical flows and verified end states with warm-up excluded, multiple runs, and failure counts. Separate local tool time from model reasoning and outer tool transport. A result for one navigation flow establishes neither other-platform performance nor superior accuracy. This import makes no benchmark claim.
