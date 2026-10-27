# AsNeeded Device Verification

This CLI is optional. Check availability and installed help; use another authorized tool or manual verification when it is missing. Do not install tools or change a device's permissions implicitly.

1. Record device ID, platform/runtime, app build, and signing type. Select the intended target explicitly and use `--device` on each command.
2. Observe the screen, act on an actually exposed selector, then verify the meaningful result. Refresh cached aliases after navigation, scrolling, rotation, or dialogs.
3. Use synthetic data. Keep private UI dumps, screenshots, recordings, and logs out of Git. Inspect actual images before asserting layout or visual parity.
4. Test the affected flow and relevant light/dark appearance, accessibility text sizes, keyboard/safe-area behavior, and compact/wide layouts. Build/tests remain separate evidence.
5. Treat iOS Simulator, physical iOS, Android, and watchOS as distinct capabilities. Physical iOS selector inspection is limited to paired, unlocked development-signed apps; TestFlight/App Store builds do not gain that support. This import establishes no watchOS automation support. Check current help before device-specific actions.
6. For 1.2.0 timing changes, verify interval-only, quantity-only, combined limits, missing history/units, edit/delete/undo, notification opt-out/denial/privacy, and both reminder types. TestFlight notification delivery and storage upgrades still need real-device testing.

No benchmark or speed superiority is claimed for this repository. Report device/build, actions, assertions, failures, and untested areas. Protected desktop Keychain dialogs are outside this mobile workflow.
