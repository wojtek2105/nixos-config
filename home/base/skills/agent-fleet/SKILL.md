---
name: agent-fleet
description: Orchestrate visible Agent Manager fleets through MCP when work benefits from multiple Pi or Codex sessions, shared tasks, groups, worktrees, file reservations, messaging, waiting, review, or session lifecycle management.
---

# Agent Fleet

Act as the coordinator of visible Agent Manager sessions. Keep ownership of the
user's requirements, decomposition, integration, review, and final answer. A
child owns only the bounded work stated in its prompt.

Agent Manager is exposed to Pi by `pi-mcp-adapter` as the `agent-manager`
server. Use the `mcp` proxy: search within that server, use the returned tool
path, and pass an argument object. Do not guess a cached prefix or schema.

```text
mcp({ search: "create session", server: "agent-manager" })
mcp({ tool: "<returned-tool-path>", args: { ... } })
```

## Decide whether to form a fleet

Delegate only an independent, bounded workstream that can run while the
coordinator continues useful work. Keep a small task local when coordination
would cost more than doing it. Never replace Agent Manager sessions with a
hidden subagent mechanism.

Before creating anything, inspect `list_sessions`, `list_groups`, the shared
task list, and file reservations. Reuse a suitable live session or group when
one already exists. Respect project instructions and the current working tree.

The root coordinator counts while it is generating. To keep the shared KV
cache within capacity, allow at most three actively generating Pi sessions at
once: normally the root plus two Pi children. More sessions may exist, but
their work must remain queued until a slot is free. Sleeping, idle, or waiting
sessions do not consume an active slot. A child may delegate another bounded
task only when it knows a slot is free and keeps the same ownership rules.

## Organize work

Use a short group path for one project or feature, with its exact repository as
the default directory. Create shared tasks for independently claimable units;
record dependencies when one result gates another. Claim before work, finish
only after the promised handoff exists, and release a claim when blocked.

For each session use a descriptive 2–4 word kebab-case name and provide:

- `tool="pi"` for ordinary local work; use `tool="codex"` only for a bounded
  problem whose difficulty justifies escalation;
- the exact group and working directory;
- one objective and an explicit read-only or write authority;
- exact files or directories it may change;
- relevant project constraints and decisions, without copying chat history;
- the end user's response language;
- the expected handoff: findings, changed files, validation evidence, risks,
  and blockers.

Prefer `worktree=true` when writers can produce independent branches. The
coordinator must remember that worktree edits do not appear in the root checkout:
inspect the worker diff and integrate deliberately. Use a shared checkout only
when agents truly need the same uncommitted state.

## Reserve shared files

Before a session edits a shared checkout, call `reserve_files` with the
smallest practical literal paths, an exclusive lease, and a concise reason.
Inspect the returned conflicts. If another session holds an overlapping lease,
stop and resolve ownership through `send_session`; do not edit through the
conflict. Release the paths immediately after the edit or handoff.

Reservations are advisory coordination leases, not filesystem locks. They
surface collisions but cannot prevent a process from writing. Worktrees remain
the stronger isolation boundary for independent changes.

## Steer and wait

Use `send_session` for scope corrections or new facts and `message_status` when
delivery matters. Do not repeatedly poll screens. Call `wait_for_session`, then
`read_session` once the target is no longer working. A timeout is a status
update, not proof of failure.

Review every child result and diff before accepting it. Verify that it stayed
inside its authority, reconcile cross-agent interface decisions, and perform
the final integration yourself. Follow the repository's rules for tests,
builds, activation, credentials, and destructive actions; delegation never
expands authorization.

## Close the fleet

Release task claims and file reservations on failure or cancellation. Kill a
session only when intentionally interrupting live work; killing keeps its row
and history. Revive a dead session when its existing context is still useful.
Archive completed sessions, then delete empty temporary groups only after their
work and handoffs are accounted for.
