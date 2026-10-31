# REC Utility

A small, pixel-style GUMMM mod for the Android version of REC. It is packaged as a ZIP for import into GUMMM; it is not a separate Android APK.

## Current target

- Game: REC Android experimental build 0.6.0.0.1
- Loader/package format: GUMMM / GUMM mod (mod.cfg + mod.gd)
- Output: REC-UTILITY.zip
- Original REC APK: left untouched

## Features in the first implementation

- In-game REC Utility panel with square, high-contrast styling.
- Catalogue of the 19 developer-provided cheat codes.
- Tap a code to place it in the visible cheat input and emit its text_submitted signal.
- Warning before repeating the resource-adding codes MONEYPLZ, YODIK, and WEIII.
- Saved shader and teleport-cursor preferences in user://rec_utility_state.cfg.
- When a matching visible Settings toggle is found, the mod reapplies the saved preference while the game is running.

The UI uses hard-edged panels and a limited pixel-art-inspired palette. No smooth decorative artwork is included.

## Important runtime limits

REC's gameplay scripts are compiled, so the mod does not assume private game methods or variable names. It uses the GUMM initialize(mod_path, scene_tree) entry point and inspects visible Godot controls at runtime.

- Cheat submission is attempted only when a unique visible LineEdit can be identified. A control whose name, placeholder, or tooltip contains cheat or code is preferred. If no unique target is found, the mod asks you to open Settings and show the cheat box.
- Shader control looks for a visible toggle labelled or named No shaders / No shader. The utility's SHADERS: ON preference means the game's inverse No shaders toggle should be OFF.
- Teleport-cursor control looks for a visible toggle labelled or named Teleport cursor.
- If REC uses custom controls, different labels, or a different submission mechanism, those controls need to be identified from a runtime test before the automation can be considered verified.

This first package is an integration build, not yet a confirmed compatibility release. Check the GUMMM loader log and the in-game status message during testing.

## Build

GitHub Actions runs scripts/validate_mod.py, packages the contents of mod/ at the ZIP root, verifies the archive layout, and uploads the ZIP as the workflow artifact REC-UTILITY-GUMMM-ZIP.

1. Open the repository's Actions tab.
2. Open Package REC Utility for GUMMM.
3. Download the REC-UTILITY-GUMMM-ZIP artifact.
4. Import the ZIP into GUMMM.

## Cheat code source notes

The code names and effects were supplied by the user from the REC developer's Discord. Compatibility notes retained:
- AMOGUS: Bugbash Build 0.5.6.4 or newer.
- STREAMER: minimum build 0.5.4.8.

Resource-adding codes can potentially stack when submitted repeatedly; the mod warns before repeating them.

## Credits

- REC cheat-code list: supplied by the user from the REC developer's Discord.
- GUMMM: DinoCDX/GUMMM.
- GUMM mod-loader contract: based on the documented GUMM initialize(mod_path, scene_tree) interface.
