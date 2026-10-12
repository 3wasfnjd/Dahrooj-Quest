# دحروج — Dahrooj · native Meta Quest version (Godot)

A native Quest app (no browser) built from the web game in the repository root,
which stays the reference for look and rules. Same units, physics, character,
park and colours: the ported code says where each piece comes from.

- Engine: Godot 4.6.3-stable, OpenXR Vendors 5.1.0 (Meta), Godot Meta Toolkit.
- Build: GitHub Actions → `.github/workflows/quest-native-apk.yml` (APK, tests, checks).
  Without signing secrets the APK uses the public TEST key in `tools/ci/test-signing`
  (sideload testing only). Store builds use `DAHROOJ_KEYSTORE_B64 / _ALIAS / _PASSWORD`.
- Tests: `tools/run_tests.sh` (headless).
- Screenshots without a headset:
  `godot --path . -- --screenshot=out.png [--view=vr|mr] [--hold] [--throw=x,y,z --after=s] [--start] [--menu]`

## First release (in progress)

Dahrooj, the park, VR and mixed reality, throwing with the hand, and the seven throwing
modes (goal, hoop, window, cans, bowling, bricks, fair). Phase 0 has the goal.

Install a sideload build: enable developer mode on the headset, then install the APK with
Meta Quest Developer Hub (or `adb install -r`).
