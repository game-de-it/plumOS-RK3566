"""Keep Core Provided as the shared RK3566 RetroArch default."""

from pathlib import Path
import sys


root = Path(sys.argv[1])
factory = root / "factory-defaults/retroarch/retroarch-bubble.cfg"
aspect = [line.partition("=")[2].strip() for line in factory.read_text().splitlines()
          if line.partition("=")[0].strip() == "aspect_ratio_index"]
# RetroArch v1.22.2 defines ASPECT_RATIO_CORE as 22.
if aspect != ['"22"']:
    raise SystemExit(f"Expected the Core Provided factory aspect in {factory}")


def update_script(path, replacements):
    source = path.read_text()
    for old, new in replacements:
        if source.count(old) != 1:
            raise SystemExit(f"Unexpected RetroArch aspect script in {path}: {old!r}")
        source = source.replace(old, new, 1)
    path.write_text(source)


update_script(root / "bin/plumos-retroarch-launch", (
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
    ('retroarch_pid=\ncleanup()', 'retroarch_pid=\ngeometry_config=\ncleanup()'),
    (
        '    [ -z "$append_config" ] || $BB rm -f "$append_config"\n',
        '    [ -z "$append_config" ] || $BB rm -f "$append_config"\n'
        '    [ -z "$geometry_config" ] || $BB rm -f "$geometry_config"\n',
    ),
    (
        'set +e\nset -- "$PLUMOS_ROOT/bin/retroarch" -v -c "$config"\n',
        '''# RetroArch serializes appended settings on exit and on Save Current
# Configuration. Keep explicit Game Gear geometry in a disposable cfg beside
# the shared one so relative paths and config includes resolve as usual.
if [ -n "$shader_preset" ] && [ "$gamegear_geometry" != core ]; then
    geometry_config=$($BB mktemp "${config%/*}/.gamegear-geometry.cfg.XXXXXX")
    $BB cp "$config" "$geometry_config"
    config=$geometry_config
fi
set +e
set -- "$PLUMOS_ROOT/bin/retroarch" -v -c "$config"
''',
    ),
))

migration = r'''# Older Game Gear launches saved this temporary viewport in the shared cfg.
# Match the old launcher settings together and migrate once, preserving other
# aspect choices and any core/content overrides in their own cfg files.
aspect_marker=$state_dir/rk3566-core-aspect-v1
if [ ! -e "$aspect_marker" ]; then
    if $BB awk -F '[[:space:]]*=[[:space:]]*' '
        $1 ~ /^(aspect_ratio_index|custom_viewport_(width|height|x|y)|video_scale_integer|video_shader_enable)$/ {
            value[$1] = $2
        }
        END {
            width = value["custom_viewport_width"]
            height = value["custom_viewport_height"]
            exit !(value["aspect_ratio_index"] == "\"23\"" &&
                   value["video_scale_integer"] == "\"false\"" &&
                   value["video_shader_enable"] == "\"true\"" &&
                   value["custom_viewport_x"] == "\"0\"" &&
                   value["custom_viewport_y"] == "\"0\"" &&
                   ((width == "\"640\"" && height == "\"480\"") ||
                    (width == "\"480\"" && height == "\"432\"")))
        }
    ' "$config"; then
        aspect_backup=$state_dir/pre-rk3566-core-aspect.cfg
        [ -e "$aspect_backup" ] || atomic_copy "$config" "$aspect_backup"
        aspect_next=${config}.next.$$
        $BB sed 's/^aspect_ratio_index[[:space:]]*=[[:space:]]*"23"$/aspect_ratio_index = "22"/' \
            "$config" >"$aspect_next"
        $BB sync
        $BB mv "$aspect_next" "$config"
        $BB sync
        result=migrated-rk3566-core-aspect
    fi
    : >"$aspect_marker"
fi

'''
marker_write = 'printf \'%s\\n\' "$factory_sha256" >"$marker.next"\n'
update_script(root / "bin/plumos-retroarch-config-merge", (
    (marker_write, migration + marker_write),
))
