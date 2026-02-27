# moai-fixer

Utility scripts for managing MoAI-ADK configuration and cleanup.

**Version:** 2.6.15 (matches moai-adk version)
**Last Updated:** 2026-02-27
**MoAI-ADK Compatibility:** 2.6.15

> **Note:** These scripts address issues in MoAI-ADK 2.6.15. Future versions of moai-adk may resolve these issues natively. Check the [moai-adk changelog](https://github.com/modu-ai/moai-adk/releases) for updates.

## Scripts

### cleanup_moai.sh

Cleanup utility for removing MoAI-related artifacts under `~/PROJECTS`.

**What It Matches:**

1. Directories ending in `/.claude/commands`
2. Directories named `.moai`, `.moai-backup`, or `.moai-backups`
3. Files (not directories) whose basename contains `moai` as a token (case-insensitive), with non-alphanumeric separators

**Safety Model:**

- Dry-run by default (lists matches only)
- Deletion requires `--delete`
- Interactive guard requires typing `DELETE` (unless `--yes` is used)
- Script self-protection: the running script is always excluded from deletion
- Root guard: `--root` must be inside `~/PROJECTS`

**Usage:**

```bash
# Preview matches (no deletion)
./cleanup_moai.sh

# Delete with interactive confirmation
./cleanup_moai.sh --delete

# Delete without prompt
./cleanup_moai.sh --delete --yes

# Optional custom root (must still be under ~/PROJECTS)
./cleanup_moai.sh --root ~/PROJECTS/some/subdir --delete
```

**Options:**

- `--root PATH`: Search root (must resolve under `~/PROJECTS`)
- `--delete`: Enable deletion mode
- `--yes`: Skip confirmation prompt (only meaningful with `--delete`)
- `--help`: Show usage

---

### fix_moai.sh

Configuration fix utility for MoAI-ADK that addresses:

- **GitHub #437**: Changes Haiku model from `glm-4.7-flashx`/`glm-4.5-air` to `glm-4.7-flash`
- **GitHub #448**: Patches session-end hook to preserve GLM env vars in persistent mode

**Usage:**

```bash
# Preview all changes
./fix_moai.sh --dry-run

# Apply all fixes to current project only
./fix_moai.sh

# Fix models only
./fix_moai.sh --models

# Fix session-end hook for all projects
./fix_moai.sh --hook --global

# Restore from backup (last backup)
./fix_moai.sh --restore

# Undo all changes (restore original files)
./fix_moai.sh --undo
```

**Options:**

- `--models`: Fix model configuration (llm.yaml, glm.md)
- `--hook`: Fix session-end hook to preserve GLM env vars
- `--all`: Apply all fixes (default if no flags specified)
- `--global`: Apply hook fix to all projects under `~/PROJECTS`
- `--dry-run`: Show changes without applying them
- `--restore`: Restore from backup (`.bak` files)
- `--undo`: Reverse all changes (restore original files)
- `--quiet`: Suppress output except errors
- `--help`: Show usage

**Files Modified:**

| File | Change |
|------|--------|
| `~/.moai/config/sections/llm.yaml` | Update `low` and `haiku` model to `glm-4.7-flash` |
| `.claude/skills/moai/team/glm.md` | Replace model references (lines 151, 172, 173) |
| `.claude/hooks/moai/handle-session-end.sh` | Add GLM mode check before calling moai binary |
| `.moai/config/sections/llm.yaml` | Project-level model config (if exists) |

**Note:** Run this script again after `moai update` as updates may overwrite changes.

---

## Update History

### Version 2.6.15 (2026-02-27)
- Aligned version numbering with moai-adk for clarity
- fix_moai.sh: Addresses GitHub #437 (model) and #448 (session-end hook)
- cleanup_moai.sh: Added version header

### cleanup_moai.sh History
- `2026-02-09`: Initial script and README created.
- `2026-02-09`: Matching changed from broad `*moai*` behavior to token-style matching in basename.
- `2026-02-09`: Safety fix: Token `moai` matching now applies to files only (not directories).
- `2026-02-09`: Directory rule expanded to also remove `.moai/` and `.moai-backup/`.

### fix_moai.sh History
- `2026-02-27`: Initial script created (addresses GitHub #437, #448).
- `2026-02-27`: Added `--undo` functionality.
