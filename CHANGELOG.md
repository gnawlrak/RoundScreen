# Changelog

## 1.0.0 — 2026-11-07

Initial public release.

- Continuous-curvature four-corner overlay for every macOS display.
- Normal `20 pt`, Maximized `14 pt`, and Fullscreen `0 pt` states.
- Per-display and per-corner window-state resolution.
- Native `AXFullScreen` detection for apps that report `visibleFrame` while fullscreen.
- Spring-animated `CGPath` transitions, including continuous `0 pt ↔ 20 pt`.
- Mission Control freeze, Space switching, Lock Screen layer handoff, and multi-display support.
- Pointer exclusion and system hot-corner proxy behind Accessibility permission.
- 28 core unit tests.
