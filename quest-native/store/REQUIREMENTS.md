# Meta Horizon Store: listing and asset requirements (Dahrooj, Quest native)

Collected on 13 October 2026 for «دحروج — Dahrooj» (`com.abodengames.dahrooj`, Aboden Games).

## How these values were checked

- **The Meta developer site could not be opened from this session.** Every request to
  `developers.meta.com` (and its `prod.` mirror) was refused by the session's network proxy,
  so no page was read in full.
- The values below come from three kinds of source. Each row says which one it rests on.
  - **Meta excerpt:** text quoted from Meta's own pages in search-engine results (the Meta
    URL is given). The figure is Meta's, but the full page could not be read around it.
  - **Meta repo:** Meta's own open-source agent guide for store submission,
    `github.com/meta-quest/agentic-tools`, skill `hz-store-submit`, read in full at commit
    `3a8553d` (23 Sep 2026).
  - **Unverified:** third-party pages or older Meta blog posts.
- **Before uploading, open each image slot in the Developer Dashboard.** The dashboard shows
  the exact size it accepts and overlays the safe areas, and it is the final authority.
  Where sources disagree, the files in `store/` follow the stricter value.

## Images

| Asset | Size (px) | Format | Rules | File in `store/art/` | Source |
|---|---|---|---|---|---|
| Hero cover | 3000 × 900 (10:3) | 24-bit PNG | The title or branding sits centred in the safe area; only less important content goes in the bleed. | `hero_3000x900.png` | Meta excerpt (asset guidelines, VRC.Quest.Asset.4) |
| Cover, landscape | 2560 × 1440 (16:9) | 24-bit PNG | Branded (shows the title). No text in the top or bottom 20%, and none in the side bleed. | `cover_landscape_2560x1440.png` | Meta excerpt (asset guidelines, VRC.Quest.Asset.3) |
| Cover, square | 1440 × 1440 (1:1) | 24-bit PNG | Same rules as the landscape cover. | `cover_square_1440x1440.png` | Meta excerpt (asset guidelines) |
| Cover, portrait | 1008 × 1440 (7:10) | 24-bit PNG | Same rules as the landscape cover. | `cover_portrait_1008x1440.png` | Meta excerpt (asset guidelines) |
| Trailer cover image | 2560 × 1440 (16:9) | 24-bit PNG | The still shown before the trailer plays. | `trailer_cover_2560x1440.png` | Meta excerpt (asset guidelines) |
| Logo | Up to 9000 × 1440 | 32-bit PNG with transparent alpha | Optional. Must read on any background. Ideally fills the frame with about 20% margin at top and bottom and 10% at the sides. | `logo_transparent_2560x1440.png` | Meta excerpt (asset guidelines, VRC.Quest.Asset.1) |
| App icon | 512 × 512 (store, mobile) | 24-bit PNG | Square corners, solid fill (the system rounds the corners). | `icon_512x512.png` | Meta excerpt (older Meta blog), unverified for 2026 |
| App icon, large | 1024 × 1024 | PNG | Meta's agent guide asks for 1024. Both sizes are supplied. | `icon_1024x1024.png` | Meta repo |
| Small landscape | 1280 × 720 | PNG | Optional; used in some store placements. | `small_landscape_1280x720.png` | Meta repo |
| Mini landscape | 1080 × 360 (older docs) | PNG | Appears only in an older Meta blog post. Not made; add it only if the dashboard asks. | (none) | Unverified |

- **Text size.** Text in artwork should be at least 24 pt. Meta lowered this from required to
  recommended in July 2024 (Meta excerpt, VRC.Quest.Asset.8). The title in every branded
  image is far larger.
- **Ownership.** Meta does not check artwork for IP. The developer must own everything shown.
  All art here comes from the game's own models and the Baloo font (OFL).

## Screenshots

- **Size and format:** 2560 × 1440 (16:9), 24-bit PNG (Meta excerpt, asset table).
- **Count:** at least 3 (Meta repo). Eight are supplied in `store/screenshots/`.
- **Content:**
  - Screenshots must come from the app itself, not mock-ups or editor views (Meta repo).
  - No added logos, text or icons, and no headsets, controllers or logos from other VR
    platforms (Meta excerpt, VRC checklist).
- **"Captured on" label:** footage captured on Quest Pro or Quest 3 should carry a
  "Captured on [device]" label (Meta excerpt).
- **How the supplied screenshots were made:**
  - They were rendered by running the real game: the same build, scenes, scripts and
    shaders, on the desktop camera at 2× size and then scaled down.
  - They were **not** captured on a headset, so they carry no "Captured on" label.
  - Reviewers compare screenshots with the real experience. Mixed-reality shots must be
    real headset captures. See the checklist.
  - To make them again: `quest-native/tools/store/build_art.sh` (xvfb + OpenGL 3). The
    helpers are under `tools/store/`, which the APK export excludes (`tools/*`).

## Trailer

- 16:9, 1080p to 2K, MP4 (H.264 video, AAC audio) (Meta excerpt).
- At most 2 minutes (Meta excerpt, VRC checklist). Meta's agent guide recommends
  30 to 60 seconds (Meta repo).
- Recommended but not required. The same content rules as screenshots apply.
- None was made: it must be recorded on the headset.

## Text fields

| Field | Meta "Providing app metadata" page (updated 20 Aug 2025) | Meta agent guide (Sep 2026) | Used in `listing_*.md` |
|---|---|---|---|
| App name | 40 characters | 30 characters | ≤ 30 |
| Short description | 500 characters | 150 characters | ≤ 150 |
| Long description | 1500 characters | 4000 characters | ≤ 1500 |

- **Sources:** the first column is a Meta excerpt from
  `developers.meta.com/vr/resources/publish-app-metadata/`; the second is the Meta repo.
- **The two disagree.** The listings fit both, so either limit is safe.

## Also required at submission

From the Meta repo unless marked otherwise.

- **Privacy policy URL:** required for every app, even a free one with no accounts.
- **Support URL or email.**
- **Category / genre, and the IARC age-rating questionnaire.**
- **Comfort rating** that matches the real movement:
  - Comfortable: stationary or teleport.
  - Moderate: slow smooth locomotion.
  - Intense: fast movement.
- **Price:** free, or paid with an MSRP.
- **Entitlement check for paid apps:**
  - The app must check entitlement within 10 seconds of launch, without needing the internet.
  - Without it the app is rejected automatically.
- **Data Use Checkup:**
  - Submitting for review revokes the app's provisional access to platform features until
    the checkup is approved.
  - Asking for a release channel above 200 non-developer users ends on-the-spot approval.
- **Packaging:**
  - Release-signed APK with signature scheme v2; arm64 only.
  - `targetSdkVersion` at least 32; `minSdkVersion` at least 29.
  - The `com.oculus.intent.category.VR` intent category.
  - A version code higher than any earlier upload.
  - The same signing key for every update.
- **Performance:**
  - A steady 72 Hz at minimum (90 Hz recommended on Quest 3).
  - No thermal throttling in the first 5 minutes.
  - Interactive within 15 seconds of launch.
  - No crash or ANR in a 15-minute session.
- **Review time:** about 1 to 2 weeks. Submit at least 2 weeks before the target date.

## Sources

**Meta pages.** Read through search excerpts only: direct fetch was blocked.

- Store asset guidelines: https://developers.meta.com/horizon/resources/asset-guidelines/
- VRC.Quest.Asset.1 (logo): https://developers.meta.com/horizon/resources/vrc-quest-asset-1/
- VRC.Quest.Asset.3 (cover art): https://developer.oculus.com/resources/vrc-quest-asset-3
- VRC.Quest.Asset.4 (hero art): https://developers.meta.com/horizon/resources/vrc-quest-asset-4/
- VRC.Quest.Asset.8 (text size): https://developers.meta.com/horizon/resources/vrc-quest-asset-8/
- VRC.Quest.Asset.10 (screenshots and trailers): https://developers.meta.com/horizon/resources/vrc-quest-asset-10/
- Providing app metadata (character limits): https://developers.meta.com/vr/resources/publish-app-metadata/
- How to prep your app for submission (blog; hero 3000×900, icon 512, screenshots 2560×1440): https://developers.meta.com/horizon/blog/how-to-prep-your-app-for-submission/
- Complete data use checkup: https://developers.meta.com/horizon/resources/publish-data-use/

**Meta repository.** Read in full.

- `meta-quest/agentic-tools`, `skills/hz-store-submit/SKILL.md` and
  `references/submission-checklist.md`, plus `skills/hz-psdk-integration/references/data-use-checkup.md`:
  https://github.com/meta-quest/agentic-tools (commit 3a8553d)

**Third party.** Used only to cross-check the image sizes.

- MetaMetadata README (store image fields: hero 3000×900, portrait 1008×1440, square 1440×1440, icon 512×512): https://github.com/threethan/MetaMetadata
- VR Tour Viewer image-asset notes: https://www.vrtourviewer.com/docs/image-assets-oculus/
