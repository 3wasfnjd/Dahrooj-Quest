# Data Use Checkup and permissions — Dahrooj (Quest native)

- **Purpose:** answers for the Developer Dashboard's Data Use Checkup (DUC), the data-safety
  and privacy questions, and the permission justifications Meta reviewers ask for.
- **Basis:** the code at `quest-native/` (version 0.9.3), with file references.
- **Keep it current:** check these answers again whenever a platform feature or a permission
  is added.

## 1. What the app actually does with data

| Area | Fact | Where in the code |
|---|---|---|
| Accounts | None. No sign-in, no user ID, no name or email. | — |
| Network | No INTERNET permission (`permissions/internet=false`). The game has no HTTP or socket code. | `export_presets.cfg`; no `HTTPRequest`, `HTTPClient` or `WebSocket` anywhere in `scripts/` |
| Analytics / ads / crash reporting | None. | — |
| Saved data | One JSON file, `user://dahrooj.json`, in the app's private storage. See the list after this table. | `scripts/core/save_data.gd` |
| Backup | Android cloud backup is off (`user_data_backup/allow=false`). The data is deleted on uninstall (`retain_data_on_uninstall=false`). | `export_presets.cfg` |
| Deletion | "Reset challenges" on the menu's General page; uninstalling removes everything. | `scripts/main.gd` (`reset`) |
| Room / scene data | Read through the Meta Scene API after the USE_SCENE runtime permission. It is used in memory for placement, spawn spots and collisions, then dropped. It is never saved or sent. | `scripts/xr/scene_surfaces.gd`, `scene_anchor_probe.gd`, `room_colliders.gd`, `scripts/game/room_spots.gd` |
| Passthrough | Drawn by the system (OpenXR alpha-blend). The app never reads camera frames: there is no `HEADSET_CAMERA` permission (`permissions/camera` is off). | `scripts/xr/xr_rig.gd` (`set_mode`) |
| Head and controller poses | Used every frame for play only; never stored. | `scripts/xr/xr_rig.gd`, `scripts/main.gd` |
| Eye, face, body and hand tracking | Not used. The matching OpenXR extensions are off in `project.godot`, so the vendors plugin adds none of those permissions. The `meta_xr_features/*_tracking=1` options in `export_presets.cfg` only take effect when the extension is enabled. | `project.godot`; vendors plugin `meta_export_plugin.cpp` |
| Meta Platform SDK | Only `initialize_platform_async(app_id)` and `entitlement_get_is_viewer_entitled_async()`, and only in store builds (CI writes the App ID from the `META_APP_ID` secret). If the user is not entitled the app quits. If the platform is unavailable, play goes on. | `scripts/core/store_entitlement.gd`, `scripts/main.gd` (`_ready`) |

The saved file holds:

- language, VR or MR choice, haptics, quality and mute settings
- throw style and shot style
- best scores and challenge progress
- styles played
- Dahrooj's look: style, colour and accessory

## 2. Data Use Checkup answers

**Platform features to request:**

- Request **none** of the gated platform features: User ID, User Profile, User Age Group,
  Friends, Blocked Users, Invites, Deep Linking, Parties, Challenges, IAP/DLC,
  Subscriptions, Avatars, Device Ban, Matchmaking.
- The game calls no API that needs them.
- The entitlement check is not one of the DUC-gated grants (Meta's DUC grant map in
  `meta-quest/agentic-tools`, `hz-psdk-integration/references/data-use-checkup.md`).
- If the dashboard asks you to certify a feature anyway, choose "not used" / "no data
  collected".

**Typical questions and answers:**

| Question | Answer |
|---|---|
| Does the app collect or store user data off the device? | No. |
| Does it share data with third parties or sell data? | No. |
| Does it use data for advertising or tracking? | No. |
| Does it collect data from children? | No. Nothing personal is collected from anyone. |
| How can users ask for deletion? | Uninstall, or "Reset challenges" in the General page. No server copy exists. Contact: the support channel in the privacy policy. |
| Privacy policy URL | https://abodengames.com/dahrooj-privacy.html (the hosted copy of `store/privacy.html`). |

**Timing (two one-way doors, from Meta's guide):**

- **Submitting revokes provisional access.** Submitting for review takes away the app's
  provisional access to platform features until the checkup is approved. Finish ALPHA
  testing of the entitlement check first.
- **Large channels end instant approval.** Asking for a release channel above 200
  non-developer users ends on-the-spot checkup approval. Later checkups go to manual review.

## 3. Permission justifications

These are the permissions in the built manifest.

- **What adds them:** the Godot OpenXR Vendors plugin 5.1, from the `[xr]` settings in
  `project.godot`.
  - `openxr/extensions/meta/render_model=true`
  - `openxr/extensions/meta/scene_api=true`
  - `openxr/extensions/meta/anchor_api=true`
  - `openxr/extensions/meta/passthrough=true`
  - `openxr/extensions/hand_tracking=false`
- **Confirm before uploading:** CI prints the real list in `apk-report.txt` (section
  "badging"). Check it there.

### `com.oculus.permission.RENDER_MODEL`

- **Why it is used:**
  - To draw the player's own Touch controllers in the game with Meta's official controller
    models.
  - `scripts/xr/xr_rig.gd` creates an `OpenXRFbRenderModel` under each grip (the right
    hand's model type set to the right controller).
  - Without it, a plain fallback controller is drawn.
- **Data:** none. The models come from the runtime and nothing leaves the device.

### `com.oculus.permission.USE_SCENE`

- **Why it is used:** mixed reality uses the room the player captured in Space Setup.
  - The walls, floor, ceiling, tables, couch, bed, storage and other furniture labels and
    sizes are read through `OpenXRFbSceneManager` (`scripts/xr/scene_surfaces.gd`, with
    `scene_anchor_probe.gd` on each entity).
  - The court is pinned to the floor or a table.
  - The seven room modes (`ROOM_MODES` in `scripts/main.gd`: Whack-a-Dahrooj, Dahrooj
    Attack, Slime, Meteors, Giant, Pop Frenzy, Gallery) take their spawn spots from these
    surfaces (`RoomSpots`).
  - Dahrooj bounces off the real walls and furniture (`room_colliders.gd`).
- **When it is asked:** a runtime permission, requested at launch in
  `scene_surfaces.gd` `attach()`.
- **If the user says no:** the game falls back to the floor only (`status = "denied"`).
- **Data:** the plane and box data are processed in memory on the device only. They are not
  saved, uploaded or shared.

### `com.oculus.permission.USE_ANCHOR_API`

- **Why it is used:**
  - The Scene API returns the room as spatial anchors. Each wall, table or couch is an
    `XRAnchor3D` that `OpenXRFbSceneManager` creates.
  - The vendors plugin therefore adds this permission whenever `scene_api` or `anchor_api`
    is on.
  - The game only reads the anchors the system already holds for the captured room. It
    does not create, save, persist or share its own spatial anchors: there is no
    `OpenXRFbSpatialAnchorManager` and no anchor UUID storage in the code.
- **Data:** stays on the device.
- **Optional clean-up, not needed for review:** `anchor_api` could be turned off in
  `project.godot`, but the permission would stay because `scene_api` needs it.

### Feature `com.oculus.feature.PASSTHROUGH` (required=false)

- **What it does:** declares that mixed reality is available.
- **No permission:** passthrough is composited by Horizon OS. The app gets no camera images.

### Not declared, on purpose

- Not declared:
  - `INTERNET`
  - camera (`horizonos.permission.HEADSET_CAMERA`)
  - microphone
  - location
  - storage
  - `EYE_TRACKING`, `FACE_TRACKING`, `BODY_TRACKING`, `HAND_TRACKING`
  - `BOUNDARY_VISIBILITY`
- **If CI's `apk-report.txt` ever lists any of these:** remove it before submission. Meta
  rejects permissions an app does not use.

## 4. Other manifest facts reviewers check (from `tools/ci/build_apk.sh`)

CI fails the build unless each of these holds:

- `targetSdkVersion` is 34
- `android.hardware.vr.headtracking` is required (true)
- `com.oculus.intent.category.VR` and the OpenXR `IMMERSIVE_HMD` category are present
- the build is arm64 only
- `com.oculus.supportedDevices` is `quest3|quest3s`
- the system splash shows the studio name (`com.oculus.ossplash`)
- with the release key, the APK carries the owner's certificate
