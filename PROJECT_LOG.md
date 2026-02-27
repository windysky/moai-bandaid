# PROJECT_LOG.md

---

## Session 2026-02-27 11:00

**Coding CLI used:** Claude Code CLI (GLM)

**Phase(s) worked on:**
- Project initialization and context understanding
- GitHub issue research (#437, #448)
- SPEC document creation
- Script implementation
- Testing and verification

**Concrete changes implemented:**
1. Created `fix_moai.sh` script with:
   - Model configuration fix (llm.yaml, glm.md)
   - Session-end hook patch for GLM mode preservation
   - Backup, restore, undo, and dry-run functionality
2. Updated `README.md` to document both scripts
3. Created SPEC document at `.moai/specs/SPEC-MOAI-FIX-001/spec.md`
4. Created research document at `.moai/specs/SPEC-MOAI-FIX-001/research.md`
5. Applied fixes to global and project configuration files

**Files/modules/functions touched:**
- `fix_moai.sh` (new) - 350+ lines bash script
- `README.md` (updated) - Added fix_moai.sh documentation
- `~/.moai/config/sections/llm.yaml` - Updated haiku model to `glm-4.7-flash`
- `.moai/config/sections/llm.yaml` - Updated haiku model to `glm-4.7-flash`
- `.claude/skills/moai/team/glm.md` - Updated model references to `glm-4.7-flash`
- `.claude/hooks/moai/handle-session-end.sh` - Added GLM mode check logic

**Key technical decisions and rationale:**
1. **Why patch hook wrapper instead of moai binary:** Binary would be overwritten on update; wrapper is project-local and user-maintainable
2. **Why `glm-4.7-flash` over `glm-4.5-air`:** User preference for newer, more capable model that's still available in Z.ai coding plans
3. **Hook patch approach:** Check `llm.yaml` for `mode: glm` or `team_mode: glm` before calling `moai hook session-end`

**Problems encountered and resolutions:**
- None. Implementation went smoothly.

**Items explicitly completed, resolved, or superseded in this session:**
- GitHub #437: Model configuration fix - **Completed**
- GitHub #448: Session-end hook bug workaround - **Completed**
- SPEC-MOAI-FIX-001: Full implementation - **Completed**

**Verification performed:**
- Manual test of `--dry-run` mode
- Manual test of `--undo` functionality (restore from backup)
- grep verification of all modified files
- Re-application of fixes after undo test

---
