# Delivery Report (light) — {taskid}

> Generated: {date} · Plan: [plan.md](plan.md)
<!-- git-flow finish sẽ chèn dòng `> MR: <url>` ngay dưới đây khi git flow bật; deliver-task để trống. -->
{mr-line-nếu-có}

## Subtasks
| # | Title | Agent | Status | Files changed |
|---|---|---|---|---|
| S1 | ... | dev-backend | implemented | src/foo.ext |

**Summary:** {N} subtasks — {implemented}/{already-done}/{partial}/{skipped}.

## Code Review
| Attempt | Approved | Blocking | Suggestions | Report |
|---|---|---|---|---|

## Tests
| Project | Status | Passed | Failed | Attempts | Report |
|---|---|---|---|---|---|

> BLOCKED projects (infra missing): ...

## Gating

- security-auditor: ran | skipped (lý do)
- docs (chronicler): ran | skipped (lý do)
- models (G4): qc-executor=<model>, reviewer=<model>, …

## Security
| Severity | Count | Status |
|---|---|---|

Security reports: `.claude/tasks/{taskid}/security/`

## Follow-ups
- [ ] <lockstep, cache eviction, blocking/finding còn lại (kèm ruleId), open items>
