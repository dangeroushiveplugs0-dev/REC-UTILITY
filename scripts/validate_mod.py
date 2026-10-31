#!/usr/bin/env python3
"""Validate the GUMMM mod source before packaging."""

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MOD = ROOT / "mod"
EXPECTED_CODES = {
    "AMOGUS", "BLOWONDICE", "CHIPBAT", "DEEPSLEEPER", "EINSTEIN",
    "MILFY", "MONEYPLZ", "NINJA", "RISELIA", "ROLEXTIME", "SLIME",
    "SLOTH", "STREAMER", "SUAVEDUDE", "TOLOVERS", "YODIK",
    "ZEDMART", "WEIII", "PEEPTUBER",
}


def main() -> None:
    cfg = MOD / "mod.cfg"
    script = MOD / "mod.gd"
    catalogue = MOD / "data" / "cheats.json"

    for required in (cfg, script, catalogue):
        if not required.is_file():
            raise SystemExit(f"Missing required mod file: {required.relative_to(ROOT)}")

    cfg_text = cfg.read_text(encoding="utf-8")
    if "[Godot Mod]" not in cfg_text or 'name = "REC Utility"' not in cfg_text:
        raise SystemExit("mod.cfg is missing the GUMMM Godot Mod metadata.")

    script_text = script.read_text(encoding="utf-8")
    for marker in ("func initialize(", "text_submitted.emit(", "func _apply_saved_game_settings(", "func _show_ui_diagnostics("):
        if marker not in script_text:
            raise SystemExit(f"mod.gd is missing required runtime marker: {marker}")

    entries = json.loads(catalogue.read_text(encoding="utf-8"))
    codes = [entry.get("code") for entry in entries]
    if len(codes) != len(set(codes)):
        raise SystemExit("Duplicate cheat code found.")
    if set(codes) != EXPECTED_CODES:
        missing = sorted(EXPECTED_CODES - set(codes))
        extra = sorted(set(codes) - EXPECTED_CODES)
        raise SystemExit(f"Cheat catalogue mismatch. Missing={missing}; extra={extra}")
    for entry in entries:
        if not re.fullmatch(r"[A-Z0-9]+", entry["code"]):
            raise SystemExit(f"Invalid cheat code spelling: {entry['code']}")
        if not entry.get("description"):
            raise SystemExit(f"Missing description for {entry['code']}")

    print(f"Validated REC Utility: {len(entries)} cheat codes; GUMMM files present.")


if __name__ == "__main__":
    main()
