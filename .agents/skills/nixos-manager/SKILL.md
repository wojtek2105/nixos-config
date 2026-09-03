---
name: nixos-manager
description: Coordinate visible Agent Manager sessions for NixOS configuration work, including Codex and local Ollama workers, file reservations, review, and integration.
---

# NixOS Manager

Coordinate Agent Manager work in this repository. The initiating session retains
ownership of requirements, review, integration, and the final response; any
visible session may delegate a genuinely independent, bounded subtask through
the same Agent Manager MCP server.

## Start and coordinate

1. Run `agent-manager rename "<broad-session-name>"` exactly once when the user asks for it. Use a 2–4 word kebab-case name for the whole session; do not retry or rename again unless the user explicitly requests it.
2. Read the applicable `AGENTS.md`, inspect `git status`, and use the shared Agent Manager task list before starting work.
3. Split only independent, bounded work into shared tasks. Do not create workers for trivial reads or a single focused edit.
4. Create visible workers with Agent Manager MCP `create_session`, a descriptive
   kebab-case name, and a full prompt. Set `tool="codex"` for Codex workers or
   choose an explicit `crabcode-*` tool for a local Ollama/Crabcode worker.
   State the chosen backend in the prompt. Use `worktree=true` for repository
   writes.
5. Before concurrent edits, reserve the exact files through Agent Manager MCP. Use messages to resolve scope changes, then wait for workers with `wait_for_session` and inspect their output before integration.

## Delegation from any session

- A manager and every worker may call `create_session` through Agent Manager MCP
  when a further subtask is independent and bounded. This creates another
  visible, controllable session; do not use hidden native subagents.
- Use `crabcode-manager` as the token-efficient root: route routine work to an
  explicit `crabcode-*` tool where the host provides one. On `izakomp`, only
  local `crabcode` and `codex` are available: keep routine work on local
  Crabcode and create Codex only for genuinely difficult work. On farm-enabled
  hosts, route difficult work through `crabcode-white-monster` first; that
  reasoning worker may create `codex` only when local analysis is insufficient.
  If White Monster is unavailable, the root may create Codex directly. All
  profiles share the same Agent Manager MCP server; `tool` chooses the CLI, not
  a different MCP server.
- Keep the delegation tree understandable: include the objective, expected
  output, authority, and exact file scope. The parent still reviews and
  integrates the child result.

## Agent profiles

- Codex root sessions and workers use `gpt-5.6-terra` with medium reasoning.
- On `izakomp`, `crabcode-manager` uses only loopback Ollama and exposes no
  remote host profiles; it may escalate difficult work directly to Codex.
- On farm-enabled hosts, `crabcode-manager` prefers Crabcode/Ollama workers. Difficult
  work goes through White Monster before Codex whenever that host is reachable;
  direct Codex is the fallback when it is unavailable. In local-only mode or
  after a usage-limit failure no layer may create or retry Codex sessions.
- Escalate reasoning effort only when a bounded task has a demonstrated need; do not make every worker high-effort by default.
- Respect the available concurrency and create only workers that improve the
  task. Use Agent Manager MCP sessions rather than native Codex subagents.

## Complete safely

- Review worker findings and diffs yourself; do not forward their conclusions unexamined.
- Preserve unrelated working-tree changes and avoid edits outside the assigned scope.
- For this NixOS repository, leave evaluation, builds, activation, service restarts, and manual desktop checks to the user. Give exact validation commands in the handoff.
