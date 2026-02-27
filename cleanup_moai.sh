#!/usr/bin/env bash
#
# cleanup_moai.sh - Cleanup utility for MoAI-ADK artifacts
#
# Version: 2.6.15 (matches moai-adk version)
# Last Updated: 2026-02-27
# MoAI-ADK Version: 2.6.15
#
set -euo pipefail

PROJECTS_ROOT="${HOME}/PROJECTS"
ROOT_DIR="$PROJECTS_ROOT"
DO_DELETE=0
ASSUME_YES=0

usage() {
  cat <<'EOF'
Usage: ./cleanup_moai.sh [--root PATH] [--delete] [--yes] [--help]

Scans under ~/PROJECTS (or a custom --root under ~/PROJECTS) and matches:
  1) directories ending in /.claude/commands
  2) directories named .moai, .moai-backup, or .moai-backups
  3) files whose basename contains "moai" as a token (case-insensitive),
     where token separators are non-alphanumeric characters

Safety defaults:
  - Dry-run by default (lists matches only)
  - Deletion only with --delete
  - Interactive confirmation ("DELETE") unless --yes is passed
  - The running script is always excluded from deletion
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      [[ $# -ge 2 ]] || { echo "Error: --root requires a path" >&2; exit 2; }
      ROOT_DIR="$2"
      shift 2
      ;;
    --delete)
      DO_DELETE=1
      shift
      ;;
    --yes)
      ASSUME_YES=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Error: unknown option: $1" >&2
      usage
      exit 2
      ;;
  esac
done

ROOT_DIR="$(readlink -f "$ROOT_DIR")"
PROJECTS_ROOT="$(readlink -f "$PROJECTS_ROOT")"
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"

if [[ "$ROOT_DIR" != "$PROJECTS_ROOT" && "$ROOT_DIR" != "$PROJECTS_ROOT/"* ]]; then
  echo "Error: --root must be within $PROJECTS_ROOT" >&2
  exit 2
fi

declare -A seen=()

# 1) directories ending in /.claude/commands
while IFS= read -r -d '' path; do
  seen["$path"]=1
done < <(find "$ROOT_DIR" -type d -path '*/.claude/commands' -print0 2>/dev/null)

# 2) directories named .moai, .moai-backup, or .moai-backups
while IFS= read -r -d '' path; do
  seen["$path"]=1
done < <(find "$ROOT_DIR" -type d \( -name '.moai' -o -name '.moai-backup' -o -name '.moai-backups' \) -print0 2>/dev/null)

# 3) files with token "moai" in basename (case-insensitive), never directories
while IFS= read -r -d '' path; do
  base="${path##*/}"
  if [[ "$base" =~ (^|[^[:alnum:]])[mM][oO][aA][iI]([^[:alnum:]]|$) ]]; then
    seen["$path"]=1
  fi
done < <(find "$ROOT_DIR" -type f -print0 2>/dev/null)

# Always exclude this script itself.
unset 'seen[$SCRIPT_PATH]' 2>/dev/null || true

if [[ ${#seen[@]} -eq 0 ]]; then
  echo "No matches found under: $ROOT_DIR"
  exit 0
fi

mapfile -t matches < <(printf '%s\n' "${!seen[@]}" | sort)

echo "Found ${#matches[@]} match(es) under: $ROOT_DIR"
for path in "${matches[@]}"; do
  printf '  %s\n' "$path"
done

if [[ $DO_DELETE -eq 0 ]]; then
  echo
  echo "Dry-run only. Re-run with --delete to remove these paths."
  exit 0
fi

if [[ $ASSUME_YES -eq 0 ]]; then
  echo
  read -r -p 'Type DELETE to confirm removal: ' confirm
  if [[ "$confirm" != "DELETE" ]]; then
    echo "Aborted. No files were deleted."
    exit 1
  fi
fi

echo
echo "Deleting ${#matches[@]} path(s)..."
for path in "${matches[@]}"; do
  if [[ "$path" == "$SCRIPT_PATH" ]]; then
    echo "  Skipping script: $path"
    continue
  fi
  rm -rf -- "$path"
  echo "  Deleted: $path"
done

echo "Done."
