# REC Utility

A GUMMM mod for the Android version of REC, including a full-screen cinematic post-process shader. It is packaged as a ZIP for import into GUMMM; it is not a separate Android APK.

## Current target

- Game: REC Android experimental build 0.6.0.0.1
- Loader/package format: GUMMM / GUMM script mod (`mod.cfg` + `mod.gd`)
- Output: `REC-UTILITY.zip`
- Original REC APK: left untouched

## GUMMM compatibility: what is and is not supported

GUMMM is **not resource-pack-only**. Its own README documents three distinct mod types: GUMM script mods, resource packs, and experimental Godot Mod Loader mods. Its Godot 4 loader source (`gumm_core4.gd`) detects `mod.gd`, loads it, creates the script instance, and calls `initialize(mod_path, scene_tree)`.

The important limitation is different: GUMMM's Godot Mod Loader hook system may require a game exported with hooks. This utility does **not** use that hook system. It uses the documented GUMM `initialize` entry point to add its own UI and inspect visible Godot controls.

That confirms the loader supports the kind of script package we are building. It does **not** prove that REC's particular cheat input and settings controls can be automated. Those are game-specific runtime details and still need an in-game test.

## Features in this integration build

- Full-screen cinematic color grade with subtle red/blue chromatic aberration, edge vignette, and restrained exposure/contrast/saturation adjustments.
- The shader is applied independently of the REC+ floating launcher; GUMMM's mod enable/disable controls the effect.
- In-game REC Utility panel with square, high-contrast styling.
- Catalogue of the 19 developer-provided cheat codes.
- Attempt to submit a selected code through the visible cheat input's `text_submitted` signal.
- Warning before repeating the resource-adding codes MONEYPLZ, YODIK, and WEIII.
- Saved shader and teleport-cursor preferences in `user://rec_utility_state.cfg`.
- Attempt to reapply saved settings when matching visible toggles are found.
- **SCAN REC UI (DIAGNOSTICS)** button to list visible input fields, buttons, labels, node names, and toggle states. This helps identify REC's actual controls without asking users to inspect decompiled scripts.

The shader is intentionally subtle and uses one full-screen pass. It does not add multi-pass bloom or heavy blur, keeping the first Android implementation relatively lightweight.

## Runtime verification still required

- The floating panel appearing in REC proves the GUMM script loaded.
- The diagnostics scan helps identify whether REC uses standard `LineEdit` / `TextEdit` inputs and standard toggle buttons.
- Cheat submission is not confirmed until REC visibly accepts a code.
- Shader and teleport-cursor controls are not confirmed until the game visibly changes and retains the selected settings.
- If REC uses custom controls or a different submission mechanism, the diagnostics output will guide the next targeted change.

This is an integration-test build, not a confirmed compatibility release. Do not treat a successful Godot parse or ZIP build as proof of in-game functionality.

## Build

GitHub Actions runs `scripts/validate_mod.py`, packages the contents of `mod/` at the ZIP root, verifies the archive layout, and uploads the ZIP as the workflow artifact `REC-UTILITY-GUMMM-ZIP`.

1. Open the repository's Actions tab.
2. Open Package REC Utility for GUMMM.
3. Download the `REC-UTILITY-GUMMM-ZIP` artifact.
4. Import the ZIP into GUMMM only when ready for the controlled compatibility test.

## Cheat code source notes

The code names and effects were supplied by the user from the REC developer's Discord. Compatibility notes retained:
- AMOGUS: Bugbash Build 0.5.6.4 or newer.
- STREAMER: minimum build 0.5.4.8.

Resource-adding codes can potentially stack when submitted repeatedly; the mod warns before repeating them.

## Credits

- REC cheat-code list: supplied by the user from the REC developer's Discord.
- GUMMM: DinoCDX/GUMMM.
- GUMM mod-loader contract: based on the documented `initialize(mod_path, scene_tree)` interface and GUMMM's Godot 4 loader implementation.
