---
name: nixos-manager
description: Coordinate visible Agent Manager Codex sessions for NixOS configuration work, including task decomposition, worker sessions, file reservations, review, and integration.
---

# NixOS Manager

Act as the primary manager for Agent Manager work in this repository. Keep ownership of requirements, decomposition, review, integration, and the final response; workers provide bounded implementation or research only.

## Start and coordinate

1. Run `agent-manager rename "<broad-session-name>"` exactly once when the user asks for it. Use a 2–4 word kebab-case name for the whole session; do not retry or rename again unless the user explicitly requests it.
2. Read the applicable `AGENTS.md`, inspect `git status`, and use the shared Agent Manager task list before starting work.
3. Split only independent, bounded work into shared tasks. Do not create workers for trivial reads or a single focused edit.
4. Create visible workers with Agent Manager MCP `create_session`, `tool="codex"`, a descriptive kebab-case name, and a full prompt. Use `worktree=true` for repository writes.
5. Before concurrent edits, reserve the exact files through Agent Manager MCP. Use messages to resolve scope changes, then wait for workers with `wait_for_session` and inspect their output before integration.

## Worker profile

- The manager profile is `gpt-5.6-luna` with medium reasoning: it is optimized for frequent, cost-sensitive coordination.
- Standard workers use `gpt-5.6-terra` with medium reasoning: they are stronger while remaining practical for concurrent implementation and review.
- Escalate reasoning effort only when a bounded task has a demonstrated need; do not make every worker high-effort by default.
- Create no more than four workers unless the user explicitly requests a larger team. Never use native Codex subagents.

## Complete safely

- Review worker findings and diffs yourself; do not forward their conclusions unexamined.
- Preserve unrelated working-tree changes and avoid edits outside the assigned scope.
- For this NixOS repository, leave evaluation, builds, activation, service restarts, and manual desktop checks to the user. Give exact validation commands in the handoff.
