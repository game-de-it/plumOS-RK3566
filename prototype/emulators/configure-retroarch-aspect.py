"""Use the shared RetroArch aspect preference for Game Gear by default."""

from pathlib import Path
import sys


root = Path(sys.argv[1])
factory = root / "factory-defaults/retroarch/retroarch-bubble.cfg"
aspect = [line.partition("=")[2].strip() for line in factory.read_text().splitlines()
          if line.partition("=")[0].strip() == "aspect_ratio_index"]
# RetroArch v1.22.2 defines ASPECT_RATIO_CORE as 22.
if aspect != ['"22"']:
    raise SystemExit(f"Expected the Core Provided factory aspect in {factory}")

launcher = root / "bin/plumos-retroarch-launch"
source = launcher.read_text()
replacements = (
    ("${PLUMOS_GAMEGEAR_LCD_GEOMETRY:-sega43}", "${PLUMOS_GAMEGEAR_LCD_GEOMETRY:-core}"),
    ("sega43|integer3x)", "core|sega43|integer3x)"),
    ("expected sega43 or integer3x", "expected core, sega43, or integer3x"),
    (
        """    printf '%s\\n' 'video_shader_enable = "true"' >>"$append_config"
""",
        """    printf '%s\\n' 'video_shader_enable = "true"' >>"$append_config"
fi

if [ -n "$shader_preset" ] && [ "$gamegear_geometry" != core ]; then
""",
    ),
)
for old, new in replacements:
    if source.count(old) != 1:
        raise SystemExit(f"Game Gear aspect block changed in {launcher}")
    source = source.replace(old, new, 1)
launcher.write_text(source)
