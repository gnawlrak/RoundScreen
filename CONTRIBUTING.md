# Contributing

Thanks for helping improve RoundScreen.

## Build and test

Requirements:

- macOS 14 or newer
- Xcode 16 or newer
- XcodeGen (only needed after editing `project.yml`)

```sh
xcodegen generate
xcodebuild -project RoundScreen.xcodeproj -scheme RoundScreen \
  -configuration Debug -derivedDataPath .build/DerivedData \
  -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO
```

For a signed local app, select your own Development Team in Xcode under
**Signing & Capabilities**. Do not commit personal team identifiers or signing
credentials.

## Pull requests

- Keep changes focused on one behavior or refactor.
- Add or update tests for geometry and display-state changes.
- Do not commit `build/`, `.build/`, profile data, or Xcode user state.
- Describe any behavior that depends on private macOS APIs, Accessibility
  permission, or a specific macOS version.

## Design constraints

- Preserve native spaces, fullscreen, Mission Control, Lock Screen, and
  multi-display behavior.
- Prefer continuous path animation over hiding or replacing system windows.
- Never upload screen contents or user data.
