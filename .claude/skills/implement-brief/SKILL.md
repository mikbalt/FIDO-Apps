---
name: implement-brief
description: Implement a FIDOSims brief (docs/briefs/0N-*.md), one of its tasks, or an agent-ready GitHub issue, following the repo workflow in AGENTS.md (branch per brief, one commit per task, tests and builds green, progress updated). Use when asked to "implement brief 03", "do T2 of brief 03", or "work on issue #4".
---

# Implement a brief, task or issue

Arguments: a brief (`03`), optionally a task (`T2`), or an issue (`#4`).

## 1. Orient (do not skip)

1. Read `AGENTS.md`, `docs/PROGRESS.md` and `docs/briefs/README.md`.
2. Read the brief in full, or the issue (`gh issue view <n> -R mikbalt/FIDO-Apps`).
3. Check the gate: a brief may start only when the previous brief's `needs-device` sign-off issue is closed.
   If it is still open, stop and tell the user which issue blocks it.
4. List the brief's tasks and acceptance criteria as a task list before writing code.

## 2. Branch

- Brief: `git switch -c brief/0N-<name> main` (or continue the existing branch).
- Issue: `git switch -c issue/<n>-<slug> main`.

## 3. For each task

1. Implement exactly what the task says. Respect the contracts and "Decisions already made" in `AGENTS.md`;
   stop and ask before changing a contract or adding a dependency.
2. Add Swift Testing tests for every acceptance criterion. Build test data in the tests (CryptoKit keys,
   `MockTransport` fixtures, `FakeAuthenticator`); never invent "real" fixtures.
3. Run `/verify-changes`. Fix everything it reports.
4. Commit: `T<n>: <what>` (or `#<issue>: <what>`), body explaining the decisions, ending with the
   `Co-Authored-By` line from the session instructions.

## 4. UI

For any change under `App/`, delegate a Simulator check to the `sim-verifier` agent with concrete
expectations (screen, inputs, exact texts). Fix reported functional or layout bugs and re-verify.

## 5. Finish

Run `/report-progress`. Do not merge to `main` or push unless the user asks.
