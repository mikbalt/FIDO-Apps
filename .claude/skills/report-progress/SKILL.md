---
name: report-progress
description: Close out FIDOSims work - update docs/PROGRESS.md, create or update GitHub issues for remaining gaps (labels brief-0N, needs-device, agent-ready, blocked), and draft the end-of-brief summary (what changed, decisions, open questions). Use at the end of a brief, task or issue, or when asked for a status report.
---

# Report progress

1. **Collect facts:** `git log --oneline main..HEAD` (or the last commits), `swift test` result, build
   result, and what was verified in the Simulator. Do not claim device verification: only Ikbal does that.
2. **Update `docs/PROGRESS.md`:** brief table, task status table for the current brief, open work table
   (with issue links), open decisions, known limitations. Change the "Last updated" date.
3. **GitHub issues** (`gh ... -R mikbalt/FIDO-Apps`; the repo is public, so never put secrets or real
   card data in issues):
   - Close issues the work resolved (`gh issue close <n> --comment "Done in <commit>"`).
   - For each remaining gap, create an issue only if none exists (`gh issue list --search`). Labels:
     `brief-0N`; `needs-device` for anything that needs the iPhone and card; `agent-ready` when an agent can
     do it without a card; `blocked` when it waits on a sign-off or decision; `question` for owner decisions.
   - At the end of a brief, make sure its "Verified by Ikbal on device" checklist exists as a `needs-device` issue.
4. **Commit** the progress update (`Progress: <what>`), unless the user said not to.
5. **Summary for the user:** what changed, the decisions made, open questions, and which issues are next.
   Keep it short; link issues by number.
