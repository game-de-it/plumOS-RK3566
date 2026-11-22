"""Add managed contentless entries to the pinned Bubble frontend."""

from pathlib import Path
import sys


def replace(path, original, replacement):
    text = path.read_text()
    if text.count(original) != 1:
        raise SystemExit(f"Unexpected Bubble source in {path.name}")
    path.write_text(text.replace(original, replacement))


source = Path(sys.argv[1])
scanner = source / "plumos_library_scan.c"
replace(scanner, "  int enabled;\n", "  int enabled;\n  char builtin_entry[256];\n")
replace(scanner, '    system.enabled = json_get_bool(obj, obj + strlen(obj), "enabled", 1);',
        '''    system.enabled = json_get_bool(obj, obj + strlen(obj), "enabled", 1);
    json_get_string(obj, obj + strlen(obj), "builtin_entry",
                    system.builtin_entry, sizeof(system.builtin_entry));''')
replace(scanner, '''    for (r = 0; r < sizeof(rom_root_names) / sizeof(rom_root_names[0]); r++) {''',
        '''    if (system->builtin_entry[0]) {
      char directory[PATH_MAX];
      char path[PATH_MAX];
      if (join_path(directory, sizeof(directory), ctx->plumos_root, "share/frontend-builtins") &&
          join_path(path, sizeof(path), directory, system->builtin_entry) &&
          access(path, R_OK) == 0) {
        add_rom_entry(ctx, s, "Built-in", path, system->builtin_entry);
      }
    }
    for (r = 0; r < sizeof(rom_root_names) / sizeof(rom_root_names[0]); r++) {''')

text_ui = source / "plumos_text_ui.c"
replace(text_ui, '''        !append_shell_quoted(plan->command, sizeof(plan->command), &pos, plan->core_path) ||
        !append_string(plan->command, sizeof(plan->command), &pos, " --rom ") ||
        !append_shell_quoted(plan->command, sizeof(plan->command), &pos, plan->rom_path)) {
      return 0;
    }''',
        '''        !append_shell_quoted(plan->command, sizeof(plan->command), &pos, plan->core_path)) {
      return 0;
    }
    if (strcmp(core_id, "2048") == 0 || strcmp(core_id, "mrboom") == 0) {
      if (!append_string(plan->command, sizeof(plan->command), &pos, " --no-content")) {
        return 0;
      }
    } else if (!append_string(plan->command, sizeof(plan->command), &pos, " --rom ") ||
               !append_shell_quoted(plan->command, sizeof(plan->command), &pos, plan->rom_path)) {
      return 0;
    }''')
