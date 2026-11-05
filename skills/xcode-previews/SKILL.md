---
name: xcode-previews
description: Build and inspect native SwiftUI preview screenshots for AsNeeded using explicit simulators and isolated preview hosts when needed.
---

# Xcode Previews for AsNeeded

Read [repository rules](../../AGENTS.md) and [design/accessibility guidance](../../ai-rules/design-accessibility.md). AsNeeded is native SwiftUI on iOS and watchOS. Preserve existing navigation, reusable components, custom font choices, `.accent`, medication colors, and supported OS versions. Use [SwiftUI Expert](../swiftui-expert-skill/SKILL.md) for implementation. Repository and user instructions override generic examples.

Use synthetic medication data for screenshots and examples. Keep manual visual/device checks separate from unit tests; do not add UI or snapshot test targets. Installing a skill does not authorize unrelated redesigns, dependency changes, downloads, account changes, or publication.

## Build and capture

Prefer the real app screen for navigation, environment, medication data, or app-wide styling. Use [sim-use](../sim-use/SKILL.md) for interactions. Enumerate installed runtimes and select an explicit simulator UDID; do not assume a hard-coded OS or whichever device happens to be booted.

```bash
xcrun simctl list devices available
xcodebuild -project AsNeeded.xcodeproj -scheme AsNeeded \
  -configuration Debug -destination 'platform=iOS Simulator,id=<UDID>' \
  -derivedDataPath /tmp/asneeded-visual-check build
xcrun simctl install <UDID> /tmp/asneeded-visual-check/Build/Products/Debug-iphonesimulator/AsNeeded.app
xcrun simctl launch <UDID> com.codedbydan.AsNeeded
xcrun simctl io <UDID> screenshot /tmp/asneeded-preview.png
```

Replace placeholders with observed values. Use synthetic data, inspect the image, and record the source revision, device, runtime, appearance, and text size. Capture the UI state relevant to the task; screenshots alone do not establish VoiceOver usability or physical-device behavior.

For a standalone SwiftUI view, use Xcode's existing `#Preview` support or a disposable preview host outside the shipping project. Supply required fonts, environment, dependencies, and synthetic fixtures; otherwise label differences from the app. Keep source files unchanged and avoid installing Ruby gems or other tooling merely to capture a preview.

## Local adaptation

The 2nd-brain preview workflow inspired this skill. Its upstream script revision and redistribution license were not established, and its dynamic mode injects targets/project files and evaluates shell commands. Those scripts are not vendored or invoked here. This installation supplies a native build/capture workflow without modifying the shipping project or adding snapshot tests. No runtime capture has been performed merely by installing this skill.
