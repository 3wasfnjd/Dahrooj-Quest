# Third-party notices — Dahrooj Quest

Audit date: 2026-10-08. Game code, Dahrooj identity, icons and original score: Aboden Games, all rights reserved unless a file says otherwise. This notice does not relicense third-party work.

## Reused assets

| Work | Source and owner | Terms | Included notice |
|---|---|---|---|
| Birch/cherry/oak GLBs, bench, lantern, pole light, explosive crate, slabs texture | Bruno Simon, Motri / [folio-2025](https://github.com/brunosimon/folio-2025), through audited legacy commit | MIT; commercial use and redistribution permitted with copyright/license | `public/licenses/motri-MIT.txt` |
| Baloo Bhaijaan 2 Arabic and Latin WOFF2, unchanged | Ek Type, legacy font assets | SIL OFL 1.1; embedding/redistribution permitted, not sold alone | `public/licenses/baloo-OFL.txt` |
| Touch controller GLBs | [WebXR Input Profiles assets](https://github.com/immersive-web/webxr-input-profiles) | MIT | `public/licenses/controller-profiles-MIT.txt` |
| Dahrooj icons and original melody | Aboden Games; owner authorized reuse in rebuild directive | Proprietary; permission for this game, not a public asset grant | `LICENSE`; `docs/asset-ledger.json` |

The ledger records each migrated file, source commit, SHA-256, ownership, commercial/redistribution rights, attribution and optimization decision. No legacy source tree was copied. Bowling pins and procedural geometry are newly authored. The new local OGG renders Aboden's existing F-major 96 BPM melody once using `scripts/render-music.mjs`; it contains no third-party recording or soundfont.

## Runtime software

IWSDK core, xr-input, locomotor and scene-composition 1.0.1: Meta Platforms and contributors, MIT. Three.js is the IWSDK-compatible `super-three@0.181.0` alias, retaining Three.js contributor notices, MIT. Havok is `@babylonjs/havok@1.3.14`, MIT. ELICS, preact signals, three-mesh-bvh and pmndrs runtime components retain their package notices. Yoga Layout 3.2.1: Meta/Facebook, MIT; its omitted npm notice is supplied from the matching upstream tag at [react/yoga v3.2.1](https://github.com/react/yoga/blob/v3.2.1/LICENSE).

`docs/dependency-licenses.json` inventories every installed non-dev dependency with its exact locked version. The build copies its notice to `public/licenses/dependencies/` and serves a JSON index. This conservative list includes dependencies removed by tree shaking; inclusion in the list does not imply execution or telemetry. The actual Rollup module inventory is a CI artifact `reports/bundled-modules.json`. Sentry server-utils 10.76.1 notice is supplied from its matching upstream release; it is not initialized as an analytics service. railroad-diagrams 1.0.0 declares CC0 in that version's README, not the license of a newer release.

**Unresolved upstream package:** `@drawcall/uikitml@0.1.8` contains no usable license declaration/text, and its public source did not establish a grant. It remains a transitive SDK install dependency, but its implementation is excluded from every production bundle by an explicit Vite alias to the project's small disabled-feature adapter. Spatial UI uses the project's own cached canvas panels. The size/license gate rejects a bundle containing that package. No rights to that fork are asserted. Do not enable or redistribute its code without obtaining a license.

## Build, development and packaging tools

Vite, TypeScript, ESLint/typescript-eslint, Vitest, Playwright and IWER are development/test tooling only; `package-lock.json` pins the resolved graph. Their upstream licenses remain applicable. No IWER runtime, simulator room or test bridge is shipped. Five production Touch profiles are selected; development simulator assets are not copied.

Official Meta Quest Bubblewrap CLI/core 1.24.1 is Apache-2.0. Generated Android wrappers use Android Browser Helper and AndroidX components under their applicable upstream notices. The final Gradle dependency report and APK contents must be audited after the real package is generated; no APK license clearance is claimed before that step. GitHub Action versions are pinned by commit. Node, Java, Android SDK and signing tools run on the cloud runner and are not added to the web application.
