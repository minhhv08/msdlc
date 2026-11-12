# Delivery Report — {id}

> Generated: {date}

## Tasks

| # | Title | Agent | Status | Files changed |
|---|---|---|---|---|
| 01 | ... | dev-backend | implemented | src/foo.ts |

**Summary:** {N} tasks — {implemented} implemented, {already-done} already-done, {partial} partial, {skipped} skipped.

## Code Review

| Attempt | Approved | Blocking | Suggestions | Report |
|---|---|---|---|---|
| 1 | No | 2 | 4 | review/review-attempt-1.md |
| 2 | Yes | 0 | 2 | review/review-attempt-2.md |

## Tests

| Project | Status | Passed | Failed | Attempts | Report |
|---|---|---|---|---|---|
| payment-service | PASS | 42 | 0 | 1 | tests/payment-service-execution-attempt-1.md |

> BLOCKED projects (infra missing): ...

## Gating

- security-auditor: ran | skipped (lý do)
- docs (chronicler): ran | skipped (lý do)
- tier (G5): <S|M|L> · models (G4/G5): planner=<model>, qc-executor=<model>, reviewer=<model>, … · max-parallel (G6): <N>
- test design: small (1 qc-designer full) | map/reduce

## Security

| Severity | Count | Status |
|---|---|---|
| Critical | 0 | — |
| High | 1 | fixed |
| Medium | 2 | followUp |

Security reports: `.claude/stories/{id}/security/`

## Follow-ups

- [ ] <lockstep, cache eviction, open items>

## Notes

<cache eviction keys cần chạy, infra còn thiếu, vi phạm rule còn lại (kèm ruleId), v.v.>
