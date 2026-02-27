#!/usr/bin/env bash
#
# fix_moai.sh - Fix MoAI-ADK configuration issues
#
# Version: 2.6.15 (matches moai-adk version)
# Last Updated: 2026-02-27
# MoAI-ADK Version: 2.6.15
#
# Addresses:
#   - GitHub #437: Change Haiku model from glm-4.7-flashx/glm-4.5-air to glm-4.7-flash
#   - GitHub #448: Fix session-end hook to preserve GLM env vars in persistent mode
#
# Usage: ./fix_moai.sh [OPTIONS]
#
set -euo pipefail

# Configuration
PROJECTS_ROOT="${HOME}/PROJECTS"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"

# Target model
TARGET_HAIKU_MODEL="glm-4.7-flash"

# Files to modify
GLOBAL_LLM_YAML="${HOME}/.moai/config/sections/llm.yaml"
GLM_SKILL_FILE=".claude/skills/moai/team/glm.md"
SESSION_END_HOOK=".claude/hooks/moai/handle-session-end.sh"
PROJECT_LLM_YAML=".moai/config/sections/llm.yaml"

# Flags
DO_MODELS=0
DO_HOOK=0
DO_GLOBAL=0
DO_DRY_RUN=0
DO_RESTORE=0
DO_UNDO=0
DO_QUIET=0

# Colors (disabled in quiet mode or non-terminal)
if [[ -t 1 ]] && [[ "$DO_QUIET" -eq 0 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# Logging functions
log_info() {
    [[ "$DO_QUIET" -eq 1 ]] || echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    [[ "$DO_QUIET" -eq 1 ]] || echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    [[ "$DO_QUIET" -eq 1 ]] || echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_dry_run() {
    [[ "$DO_QUIET" -eq 1 ]] || echo -e "${YELLOW}[DRY-RUN]${NC} $1"
}

# Usage
usage() {
    cat <<'EOF'
Usage: ./fix_moai.sh [OPTIONS]

Fix MoAI-ADK configuration issues:
  - GitHub #437: Change Haiku model to glm-4.7-flash
  - GitHub #448: Fix session-end hook to preserve GLM env vars

Options:
  --models           Fix model configuration (llm.yaml, glm.md)
  --hook             Fix session-end hook to preserve GLM env vars
  --all              Apply all fixes (default if no flags specified)
  --global           Apply hook fix to all projects under ~/PROJECTS
  --dry-run          Show changes without applying them
  --restore          Restore from backup (.bak files)
  --undo             Reverse all changes (restore original files)
  --quiet            Suppress output except errors
  --help             Show this help message

Examples:
  ./fix_moai.sh --dry-run           # Preview all changes
  ./fix_moai.sh                     # Apply all fixes to current project
  ./fix_moai.sh --models            # Fix models only
  ./fix_moai.sh --hook --global     # Fix hook for all projects
  ./fix_moai.sh --undo              # Reverse all changes

Files Modified:
  ~/.moai/config/sections/llm.yaml  # Global LLM config
  .claude/skills/moai/team/glm.md   # GLM skill file
  .claude/hooks/moai/handle-session-end.sh  # Session-end hook
  .moai/config/sections/llm.yaml    # Project LLM config (if exists)

Note: Run this script again after `moai update` as updates may overwrite changes.
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --models)
            DO_MODELS=1
            shift
            ;;
        --hook)
            DO_HOOK=1
            shift
            ;;
        --all)
            DO_MODELS=1
            DO_HOOK=1
            shift
            ;;
        --global)
            DO_GLOBAL=1
            shift
            ;;
        --dry-run)
            DO_DRY_RUN=1
            shift
            ;;
        --restore)
            DO_RESTORE=1
            shift
            ;;
        --undo)
            DO_UNDO=1
            shift
            ;;
        --quiet)
            DO_QUIET=1
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 2
            ;;
    esac
done

# Default to --all if no action specified
if [[ "$DO_MODELS" -eq 0 ]] && [[ "$DO_HOOK" -eq 0 ]] && [[ "$DO_RESTORE" -eq 0 ]] && [[ "$DO_UNDO" -eq 0 ]]; then
    DO_MODELS=1
    DO_HOOK=1
fi

# Backup file
backup_file() {
    local file="$1"
    local backup="${file}.bak"

    if [[ "$DO_DRY_RUN" -eq 1 ]]; then
        log_dry_run "Would backup: $file -> $backup"
        return 0
    fi

    if [[ -f "$file" ]]; then
        cp "$file" "$backup"
        log_info "Backed up: $file -> $backup"
    fi
}

# Restore file from backup
restore_file() {
    local file="$1"
    local backup="${file}.bak"

    if [[ "$DO_DRY_RUN" -eq 1 ]]; then
        log_dry_run "Would restore: $backup -> $file"
        return 0
    fi

    if [[ -f "$backup" ]]; then
        mv "$backup" "$file"
        log_success "Restored: $backup -> $file"
    else
        log_warn "No backup found: $backup"
    fi
}

# Check if backup exists
has_backup() {
    local file="$1"
    local backup="${file}.bak"
    [[ -f "$backup" ]]
}

# Fix global LLM YAML
fix_global_llm_yaml() {
    local file="$GLOBAL_LLM_YAML"

    if [[ ! -f "$file" ]]; then
        log_warn "Global LLM config not found: $file"
        return 0
    fi

    if [[ "$DO_DRY_RUN" -eq 1 ]]; then
        log_dry_run "Would update: $file"
        log_dry_run "  - Replace 'glm-4.7-flashx' with '${TARGET_HAIKU_MODEL}'"
        log_dry_run "  - Replace 'glm-4.5-air' with '${TARGET_HAIKU_MODEL}'"
        return 0
    fi

    backup_file "$file"

    # Replace old models with target model
    sed -i \
        -e "s/glm-4\.7-flashx/${TARGET_HAIKU_MODEL}/g" \
        -e "s/glm-4\.5-air/${TARGET_HAIKU_MODEL}/g" \
        "$file"

    log_success "Updated: $file (haiku model -> ${TARGET_HAIKU_MODEL})"
}

# Fix project LLM YAML
fix_project_llm_yaml() {
    local project_dir="${1:-$SCRIPT_DIR}"
    local file="${project_dir}/${PROJECT_LLM_YAML}"

    if [[ ! -f "$file" ]]; then
        log_info "Project LLM config not found: $file"
        return 0
    fi

    if [[ "$DO_DRY_RUN" -eq 1 ]]; then
        log_dry_run "Would update: $file"
        log_dry_run "  - Replace 'glm-4.7-flashx' with '${TARGET_HAIKU_MODEL}'"
        log_dry_run "  - Replace 'glm-4.5-air' with '${TARGET_HAIKU_MODEL}'"
        return 0
    fi

    backup_file "$file"

    # Replace old models with target model
    sed -i \
        -e "s/glm-4\.7-flashx/${TARGET_HAIKU_MODEL}/g" \
        -e "s/glm-4\.5-air/${TARGET_HAIKU_MODEL}/g" \
        "$file"

    log_success "Updated: $file (haiku model -> ${TARGET_HAIKU_MODEL})"
}

# Fix GLM skill file
fix_glm_skill() {
    local project_dir="${1:-$SCRIPT_DIR}"
    local file="${project_dir}/${GLM_SKILL_FILE}"

    if [[ ! -f "$file" ]]; then
        log_warn "GLM skill file not found: $file"
        return 0
    fi

    if [[ "$DO_DRY_RUN" -eq 1 ]]; then
        log_dry_run "Would update: $file"
        log_dry_run "  - Replace 'glm-4.5-air' with '${TARGET_HAIKU_MODEL}' (lines 151, 172, 173)"
        log_dry_run "  - Replace 'glm-4.7-flashx' with '${TARGET_HAIKU_MODEL}'"
        return 0
    fi

    backup_file "$file"

    # Replace model references
    sed -i \
        -e "s/glm-4\.5-air/${TARGET_HAIKU_MODEL}/g" \
        -e "s/glm-4\.7-flashx/${TARGET_HAIKU_MODEL}/g" \
        "$file"

    log_success "Updated: $file (haiku model -> ${TARGET_HAIKU_MODEL})"
}

# Check if hook is already patched
is_hook_patched() {
    local file="$1"
    grep -q "Check if persistent GLM mode" "$file" 2>/dev/null
}

# Fix session-end hook
fix_session_end_hook() {
    local project_dir="${1:-$SCRIPT_DIR}"
    local file="${project_dir}/${SESSION_END_HOOK}"

    if [[ ! -f "$file" ]]; then
        log_warn "Session-end hook not found: $file"
        return 0
    fi

    if is_hook_patched "$file"; then
        log_info "Already patched: $file"
        return 0
    fi

    if [[ "$DO_DRY_RUN" -eq 1 ]]; then
        log_dry_run "Would patch: $file"
        log_dry_run "  - Add GLM mode check before calling moai binary"
        return 0
    fi

    backup_file "$file"

    # Create patched version
    local patched_file="${file}.patched"

    cat > "$patched_file" << 'PATCHED_EOF'
#!/bin/bash
# MoAI SessionEnd Hook Wrapper - Generated by moai-adk
# This script forwards stdin JSON to the moai hook session-end command.
# Project-local hook: .claude/hooks/moai/session-end.sh
#
# PATCHED by fix_moai.sh - Added GLM mode check to preserve env vars
# See: GitHub #448

# Create temp file to store stdin
temp_file=$(mktemp)
trap 'rm -f "$temp_file"' EXIT

# Read stdin into temp file
cat > "$temp_file"

# Check if persistent GLM mode before removing env vars
_llm_yaml=""
if [ -f "$HOME/.moai/config/sections/llm.yaml" ]; then
    _llm_yaml="$HOME/.moai/config/sections/llm.yaml"
elif [ -n "$CLAUDE_PROJECT_DIR" ] && [ -f "$CLAUDE_PROJECT_DIR/.moai/config/sections/llm.yaml" ]; then
    _llm_yaml="$CLAUDE_PROJECT_DIR/.moai/config/sections/llm.yaml"
fi

if [ -n "$_llm_yaml" ]; then
    _mode=$(grep -E '^\s*mode:\s*"' "$_llm_yaml" 2>/dev/null | head -1 | sed 's/.*"\([^"]*\)".*/\1/')
    _team_mode=$(grep -E '^\s*team_mode:\s*' "$_llm_yaml" 2>/dev/null | head -1 | sed 's/.*:\s*\(.*\)/\1/' | tr -d ' "')
    if [ "$_mode" = "glm" ] || [ "$_team_mode" = "glm" ]; then
        # Persistent GLM mode - do NOT remove GLM env vars
        exit 0
    fi
fi

# Try moai command in PATH
if command -v moai &> /dev/null; then
	exec moai hook session-end < "$temp_file"
fi

# Try detected Go bin path from initialization
if [ -f "/home/juhur/go/bin/moai" ]; then
	exec "/home/juhur/go/bin/moai" hook session-end < "$temp_file"
fi

# Try default ~/go/bin/moai
if [ -f "/home/juhur/go/bin/moai" ]; then
	exec "/home/juhur/go/bin/moai" hook session-end < "$temp_file"
fi

# Not found - exit silently (Claude Code handles missing hooks gracefully)
exit 0
PATCHED_EOF

    # Preserve permissions
    chmod --reference="$file" "$patched_file"

    # Replace original
    mv "$patched_file" "$file"

    log_success "Patched: $file (added GLM mode check)"
}

# Find all projects with session-end hook
find_projects_with_hook() {
    find "$PROJECTS_ROOT" -type f -name "handle-session-end.sh" -path "*/.claude/hooks/moai/*" 2>/dev/null
}

# Restore from backup
do_restore() {
    log_info "Restoring from backups..."

    # Restore global LLM YAML
    if has_backup "$GLOBAL_LLM_YAML"; then
        restore_file "$GLOBAL_LLM_YAML"
    fi

    # Restore project files
    local project_dir="${1:-$SCRIPT_DIR}"

    if has_backup "${project_dir}/${PROJECT_LLM_YAML}"; then
        restore_file "${project_dir}/${PROJECT_LLM_YAML}"
    fi

    if has_backup "${project_dir}/${GLM_SKILL_FILE}"; then
        restore_file "${project_dir}/${GLM_SKILL_FILE}"
    fi

    if has_backup "${project_dir}/${SESSION_END_HOOK}"; then
        restore_file "${project_dir}/${SESSION_END_HOOK}"
    fi

    # Restore global projects if --global was used
    if [[ "$DO_GLOBAL" -eq 1 ]]; then
        while IFS= read -r hook_file; do
            local project_dir
            project_dir=$(dirname "$(dirname "$(dirname "$(dirname "$hook_file")")")")
            if has_backup "${project_dir}/${SESSION_END_HOOK}"; then
                restore_file "${project_dir}/${SESSION_END_HOOK}"
            fi
        done < <(find_projects_with_hook)
    fi

    log_success "Restore complete"
}

# Undo all changes
do_undo() {
    log_info "Undoing all changes..."

    # Restore global LLM YAML
    if has_backup "$GLOBAL_LLM_YAML"; then
        restore_file "$GLOBAL_LLM_YAML"
    fi

    # Restore project files in current directory
    local project_dir="${1:-$SCRIPT_DIR}"

    if has_backup "${project_dir}/${PROJECT_LLM_YAML}"; then
        restore_file "${project_dir}/${PROJECT_LLM_YAML}"
    fi

    if has_backup "${project_dir}/${GLM_SKILL_FILE}"; then
        restore_file "${project_dir}/${GLM_SKILL_FILE}"
    fi

    # For hook, we need to restore and also remove the patch marker
    local hook_file="${project_dir}/${SESSION_END_HOOK}"
    if has_backup "$hook_file"; then
        restore_file "$hook_file"
    elif is_hook_patched "$hook_file"; then
        # If no backup but patched, we need to regenerate (warn user)
        log_warn "Hook is patched but no backup exists: $hook_file"
        log_warn "Run 'moai init' to regenerate the original hook"
    fi

    # Undo global projects if --global was used
    if [[ "$DO_GLOBAL" -eq 1 ]]; then
        while IFS= read -r hook_file; do
            local proj_dir
            proj_dir=$(dirname "$(dirname "$(dirname "$(dirname "$hook_file")")")")
            if has_backup "${proj_dir}/${SESSION_END_HOOK}"; then
                restore_file "${proj_dir}/${SESSION_END_HOOK}"
            fi
        done < <(find_projects_with_hook)
    fi

    log_success "Undo complete"
}

# Main
main() {
    log_info "MoAI Fix Script v2.6.15 (moai-adk)"
    log_info "Target Haiku model: ${TARGET_HAIKU_MODEL}"
    echo ""

    # Handle restore
    if [[ "$DO_RESTORE" -eq 1 ]]; then
        do_restore "$SCRIPT_DIR"
        exit 0
    fi

    # Handle undo
    if [[ "$DO_UNDO" -eq 1 ]]; then
        do_undo "$SCRIPT_DIR"
        exit 0
    fi

    # Fix models
    if [[ "$DO_MODELS" -eq 1 ]]; then
        log_info "Fixing model configuration..."

        # Global LLM YAML
        fix_global_llm_yaml

        # Project LLM YAML
        fix_project_llm_yaml "$SCRIPT_DIR"

        # GLM skill file
        fix_glm_skill "$SCRIPT_DIR"

        echo ""
    fi

    # Fix session-end hook
    if [[ "$DO_HOOK" -eq 1 ]]; then
        log_info "Fixing session-end hook..."

        if [[ "$DO_GLOBAL" -eq 1 ]]; then
            log_info "Applying to all projects under: $PROJECTS_ROOT"

            local count=0
            while IFS= read -r hook_file; do
                local project_dir
                project_dir=$(dirname "$(dirname "$(dirname "$(dirname "$hook_file")")")")
                fix_session_end_hook "$project_dir"
                ((count++)) || true
            done < <(find_projects_with_hook)

            if [[ "$count" -eq 0 ]]; then
                log_warn "No projects with session-end hook found"
            else
                log_success "Patched $count project(s)"
            fi
        else
            fix_session_end_hook "$SCRIPT_DIR"
        fi

        echo ""
    fi

    # Summary
    if [[ "$DO_DRY_RUN" -eq 1 ]]; then
        log_info "Dry-run complete. No files were modified."
        log_info "Run without --dry-run to apply changes."
    else
        log_success "All fixes applied successfully!"
        log_info "Note: Re-run this script after 'moai update' as updates may overwrite changes."
    fi
}

main "$@"
