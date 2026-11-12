# Changelog

## [Unreleased]

### Added — tương thích DeepSeek harness

- `.deepseek-plugin/agent-models.toml`: routing hai tầng `deepseek-chat` / `deepseek-reasoner` theo agent.
- `deliver`, `deliver-story`, `deliver-task`, `tracking-poll`, `log-triage`, `gating.md` (G4) và README có nhánh DeepSeek, theo mẫu Codex hiện có. `agents/*.md` không đổi.

## [0.18.0] — 2026-11-12

### Added — cấu hình số agent chạy cùng lúc (G6)

- **`max-parallel-agents`** trong mục `## Pipeline` của `.claude/msdlc.md` (mặc định **4**; thiếu/không hợp lệ → 4; `1` = tuần tự). Trước đây wave dev gom tới ~6 task, cộng thêm `qc-designer` ở Wave 1 và `qc-executor` × project + `security-auditor` ở Phase 3 — có thể chạy 10+ agent cùng lúc.
- Mỗi message phát tối đa N Agent (message kế tiếp sau khi message trước trả về; không dùng chạy nền để lách). Wave dev tối đa N subtask; Wave 1: dev ưu tiên, `qc-designer` lấp slot trống, phần dư sang wave sau và phải xong trước Phase 3; Phase 1 `dev-leader` ∥ `qc-leader` cần 2 slot (N = 1 → tuần tự); Phase 3 chia batch khi vượt N, `security-auditor` vào batch đầu. Áp cho cả `deliver-story` lẫn `deliver-task` (đọc `gating.md` ở đầu Phase 1). Report ghi `max-parallel`.
- Chi tiết ở `gating.md` mục G6. Tổng token gần như không đổi; đổi lại pipeline chậm hơn khi hạ N, giảm đỉnh rate-limit/tải máy.

## [0.17.0] — 2026-11-12

### Changed — ADR phải chốt hết giả định/câu hỏi mới được duyệt

- **Gate `/deliver` (story) có vòng làm rõ bắt buộc trước khi xin duyệt.** Main đếm mục chưa chốt trong mục *Giả định & câu hỏi cần chốt* của `adr.md` (Grep `- [ ]`); còn mục nào → **không xin duyệt**, hỏi user trực tiếp bằng `AskUserQuestion` (≤ 4 câu/lần; đề xuất của architect làm option đầu "(Recommended)", kèm phương án khác và "Đưa ra ngoài scope"; không có `AskUserQuestion` thì hỏi từng câu trong chat). Không để mục treo: "chưa biết" → chốt theo đề xuất kèm rủi ro hoặc đưa ra ngoài scope.
  - Trả lời = đề xuất / xác nhận giả định / ngoài scope → main `Edit` thẳng ADR (`- [x] … → **Chốt:** …`), không tốn lượt architect. Trả lời đổi thiết kế (chọn phương án khác, thông tin mới) → chạy lại `architect` ở **chế độ cập nhật** (nâng một bậc model theo G5), lặp tới khi hết mục; tối đa 3 lần chạy lại/ADR.
  - Ghi `Status: Accepted` (bước 9) và `deliver-story` (tiền đề) đều kiểm lại: còn `- [ ]` thì từ chối, kể cả header đã `Accepted`.
- **`architect` tự chốt tối đa, chỉ để lại mục `- [ ]` khi thiếu thông tin chỉ user biết hoặc giả định thật sự chi phối thiết kế;** mỗi mục viết dạng hỏi được bằng lựa chọn (câu hỏi + đề xuất + phương án khác + ảnh hưởng). Mục 4 của ADR đổi thành checklist `- [ ]`/`- [x]`; thêm chế độ cập nhật (sửa tại chỗ bằng `Edit`). Architect không có công cụ hỏi user nên không tự đánh `[x]`.
- ADR cũ (mục "Assumptions & Open questions" không có checkbox) vẫn chạy: main coi mục chưa có quyết định rõ là chưa chốt. Luồng task (`plan.md`) và poll không đổi.

## [0.16.0] — 2026-11-12

### Changed — hạ chi phí model theo độ lớn việc (G5)

- **G5 trong `gating.md`: chọn `model` cho agent lập kế hoạch theo tier S/M/L.** Story: N = mục Functional + Acceptance; tín hiệu nặng = đổi lockstep dùng chung / tích hợp ngoài mới / NFR nặng / ≥ 3 project; S = N ≤ 8 không tín hiệu, L = N ≥ 20 hoặc ≥ 2 tín hiệu. Task: S = fixbug / mô tả ngắn rõ scope / ticket từ `log-triage`.
  - `architect`: S `sonnet`, M `opus`, L `fable` (mặc định); `dev-leader`: S `sonnet`; `qc-leader` enumerate: M `sonnet`; `task-planner`: S `sonnet`. Trước đây `architect` luôn `fable`, `dev-leader`/`task-planner` luôn `opus`.
  - Tier tính trước ADR (cho architect) và sau ADR (cho dev-leader/qc-leader); tier S sau ADR = "story nhỏ" của G3.
  - **Lưới an toàn:** người vẫn duyệt ADR/plan ở gate; chạy lại sau góp ý của người tự **nâng một bậc**; `task-planner` chế độ cập nhật ở Bước 2 của poll (chỉ fold câu trả lời) luôn `sonnet`; tóm tắt gate ghi tier + model đã dùng; `dev-leader` không hạ ở M vì `touchesFiles` thiếu có thể làm hai dev đè file.
- **G4 thêm `chronicler` → `haiku`** khi diff ≤ 5 file (đã qua gating G2).
- `deliver/story.md`, `deliver/task.md`, `deliver-story`, `qc-mapreduce.md`, `poll-run` truyền `model` theo G5; report ghi `tier` + model từng agent. `model-downgrade: never` tắt cả G4 lẫn G5. Không đổi định nghĩa agent hay contract JSON; Codex/DeepSeek bỏ qua G5.

## [0.15.0] — 2026-11-09

### Changed — bỏ bước `qc-leader` merge trong pipeline

- **Main tự ghép `tests/README.md`** ở nhánh map/reduce thay vì gọi lại `qc-leader` (opus) chỉ để đọc lại toàn bộ `testcases-part-*.md`. Traceability Matrix dựng từ stub (id/title/source/type/priority) của bước enumerate; Coverage & Gaps = `coverageGaps` + `gaps` của từng designer + stub chưa thiết kế + bucket lỗi; thêm bảng phân bố theo `type`. Không đọc lại file part (chỉ Grep id khi JSON designer thiếu để đối chiếu).
- **`qc-designer` design-subset trả thêm `designed[]` và `gaps[]`** (contract mở rộng, field mới tuỳ chọn về mặt tương thích).
- **`qc-leader` enumerate kiêm vai coverage critic** (vùng `type` mỏng, lockstep chưa có test) vì không còn lượt merge sau. Chế độ merge giữ lại cho dùng tay.
- Lý do không gộp `dev-leader` + `qc-leader`: chỉ tiết kiệm một lượt overhead (~2–5% story lớn) nhưng mất song song Phase 1, làm test bám theo cách vỡ task (mất tính độc lập), và context agent gộp phình vì phần dò code.

## [0.14.0] — 2026-11-09

### Changed — tối ưu token (đợt 6)

- **ADR chia theo người đọc:** `adr.md` là lõi (mục tiêu ≤ ~80 dòng: Status, Context, Decision tóm tắt kèm điều cố ý không làm, Consequences ≤ 5 bullet, Assumptions & Open questions, Impacted artifacts, mục lục). Chi tiết dài tách ra `adr/design.md` (mục `## D1…` theo project/component) và `adr/alternatives.md` (chỉ cho người — không agent nào đọc). Story nhỏ vẫn chỉ một file. Người đọc chỉ đọc phần cần: `dev-leader` đọc `adr.md` + `design.md`; `qc-leader`/`qc-designer`/`reviewer` đọc `adr.md` + các mục `D…` liên quan; dev trỏ tới mục cụ thể (`adr/design.md §D2`). ADR cũ (không có thư mục `adr/`) vẫn được đọc nguyên file. Header `Status:` vẫn ở `adr.md` nên gate/`deliver-story` không đổi. Mục ADR đánh số lại 1–5 (Alternatives chuyển sang file riêng).
- **`MEMORY.md` mỗi agent tối đa ~30 dòng** (nạp vào mọi lần gọi agent): sắp vượt thì gộp/xoá trước khi thêm.
- **`/msdlc:log-triage` gộp log trùng trước khi phân loại:** file lớn không còn bị `Read` nguyên; dùng Bash lọc dòng lỗi → chuẩn hoá phần biến thiên → `uniq -c` ra chữ ký + số lần → một mẫu stack trace mỗi chữ ký → ghi `.claude/bug-triage/digest-<ngày>.md` và đưa digest (không phải log thô) cho `bug-triage`. Command thêm `Bash` vào `allowed-tools`.
- **`deliver` tách theo nhánh:** `skills/deliver/story.md` / `task.md`, chỉ đọc file đúng loại id (SKILL.md 8.8KB → 2.4KB).
- **`reviewer` đọc rule theo phạm vi diff:** luôn `global` + `testing`; `backend`/`frontend` theo loại code trong diff; `security` chỉ khi chạy `securityLite`.

## [0.13.0] — 2026-11-09

### Changed — tối ưu token (đợt 5: chi phí lúc chạy)

- **`qc-executor` không đổ cả log test vào context:** ưu tiên reporter gọn/fail-only của test runner, ghi output đầy đủ ra file log trong thư mục story/task rồi chỉ `tail` phần tổng kết và `grep` đoạn quanh từng test fail (assertion + ~15 frame trỏ vào code dự án); tối đa ~10 failure chi tiết, phần còn lại chỉ liệt kê tên + đường dẫn log.
- **Mục "Đọc code tiết kiệm" cho mọi agent đọc code** (dev-backend, dev-frontend, dev-leader, reviewer, architect, task-planner, security-auditor, bug-triage, chronicler): bắt đầu từ đường dẫn được giao; Grep/Glob định vị rồi Read đúng đoạn (`offset`/`limit`) với file lớn; 1–2 file mẫu là đủ; không đọc lại; giới hạn output lệnh.
- **Bàn giao kết quả dò code cho dev:** task file của `dev-leader` có thêm dòng **Read first** trong mục Context (code cần sửa + file mẫu, kèm vị trí); subtask trong `plan.md` của `task-planner` có trường tuỳ chọn **`readFirst`** và mục 2 ghi kèm vị trí hàm/dòng. `deliver-story`/`deliver-task` chỉ thị dev bắt đầu từ đó thay vì dò lại codebase. Contract JSON không đổi (chỉ thêm trường tuỳ chọn).

## [0.12.0] — 2026-11-09

### Changed — tối ưu token (đợt 4)

- **`/msdlc:tracking-poll` có đường thoát nhanh khi rảnh.** Command chỉ còn guard + **Bước Q quét nhanh** (task local dở dang, ticket cột intake, ticket Approved đủ điều kiện) — không có gì thì dừng với một dòng. Logic chi tiết (Bước R/1/2/3/4) chuyển sang skill nội bộ mới **`msdlc:poll-run`**, chỉ nạp khi có việc và dùng lại kết quả quét (không fetch lại). Command 18KB → ~4KB mỗi lượt `/loop` rảnh.
- **Vòng fix kiểm lại đúng chỗ đã sửa (chế độ `verify`):** `reviewer` re-review chỉ kiểm finding cũ + lỗi mới do phần sửa; `security-auditor` re-audit chỉ kiểm Critical/High cũ. Agent dev sửa lỗi chỉ nhận danh sách finding/failure + file liên quan. Contract JSON không đổi.
- **G4 — model theo lần gọi** (`gating.md`): `qc-executor` chạy `haiku` (lên model mặc định khi lỗi khó chẩn đoán); `reviewer` chạy `sonnet` khi diff nhỏ (≤ ~150 dòng, ≤ 5 file, không chạm vùng nhạy cảm) và ở chế độ `verify`; `security-auditor` `verify` chạy `sonnet`. Tắt bằng `model-downgrade: never`. Codex vẫn theo `agent-models.toml`.
- **Tách cấu hình điều phối ra `.claude/msdlc.md`** (template mới `shared/msdlc.template.md`): `## Task tracker`, `## Git`, `## Pipeline` chỉ main agent đọc, nên không còn nằm trong `profile.md` mà mọi subagent phải đọc. **Tương thích ngược:** chưa có `msdlc.md` → đọc các mục cũ trong profile. `/msdlc:init` tạo `msdlc.md` cho dự án mới và (Bước 2e) đề xuất chuyển mục cũ sang.
- **Nạp theo nhánh:** phần map/reduce thiết kế test của `deliver-story` sang `skills/deliver-story/qc-mapreduce.md` (chỉ đọc khi G3 chọn map/reduce); `spec` tách `story.md` / `task.md`, chỉ đọc file của nhánh đã phân loại.

## [0.11.0] — 2026-11-09

### Changed — tối ưu token (nhóm B: bỏ agent không cần)

- **Gating mới `skills/deliver-story/gating.md`** (dùng chung cho `deliver-story` và `deliver-task`), override qua mục `## Pipeline` mới trong `profile.template.md` (`security-audit` / `docs-sync` / `qc-design`: `auto` | `always` | …; vắng mục = `auto`). Mọi lần bỏ qua ghi `skipped (lý do)` vào report (mục `## Gating` mới trong template report).
  - **G1 — `security-auditor` chỉ chạy khi diff chạm vùng nhạy cảm** (auth/authz, crypto/secret, upload/path, endpoint, truy vấn động, deserialize, outbound HTTP, cấu hình bảo mật, dependency, `security-sensitive-paths` của profile, hoặc rule `R-SEC-*` `MUST` khớp scope). Không chạy → `reviewer` nhận cờ `securityLite: true` và kiêm checklist bảo mật nhanh (finding nghiêm trọng vào `blockingFindings`).
  - **G2 — `chronicler` chỉ chạy khi thay đổi ảnh hưởng tài liệu** (public API/contract, config/env/CLI, build/deps, docs đang nhắc tới file/symbol bị đổi, followUps về docs, hoặc rule DoD bắt buộc).
  - **G3 — story nhỏ bỏ QC map/reduce**: ≤ 8 mục requirement/acceptance và ≤ 2 project → không gọi `qc-leader`, chỉ một `qc-designer` chế độ full ghi thẳng `tests/README.md` (trả `{ file, casesWritten, gaps, followUps }`). Map/reduce mà enumerate ra đúng 1 bucket → bỏ bước merge, main tự ghi `tests/README.md` gọn.
- **`dev-leader` gom task theo cụm việc** (mặc định ≤ 3 task/project; migration+model+repository+service của một entity là MỘT task; test nằm trong task thay vì task test riêng). Mỗi task file có mục **Context** tự đủ (quyết định ADR liên quan, lockstep/cache, rule id) → dev chỉ đọc `adr.md` khi Context ghi rõ cần.
- Contract JSON không đổi, trừ việc `qc-designer` full mode giờ cũng trả JSON khi pipeline gọi.
- **Thay đổi hành vi mặc định:** dự án muốn giữ y như cũ đặt `security-audit: always`, `docs-sync: always`, `qc-design: always-mapreduce` trong `## Pipeline` của profile.

## [0.10.0] — 2026-11-09

### Changed — tối ưu token (nhóm A)

- **`shared/agent-memory.md` rút từ ~140 dòng (11.6KB) xuống ~40 dòng.** Bỏ phần lặp với cơ chế `memory: local` có sẵn của Claude Code. Agent mặc định **không đọc** file này; chỉ đọc khi định ghi một memory không hiển nhiên. Mục memory trong mọi agent gom thành 1 đoạn (kèm gợi ý điều đáng ghi riêng từng agent), bỏ danh sách "Examples of what to record" vốn mâu thuẫn với quy tắc "không lưu convention/kiến trúc". Dự án đã init trước đây vẫn giữ bản cũ (init không ghi đè) — xoá `.claude/shared/agent-memory.md` rồi chạy lại `/msdlc:init` nếu muốn bản gọn; dù vậy agent vẫn chỉ đọc file khi định ghi memory.
- **Gọi `msdlc:tracking` / `msdlc:git-flow` tiết kiệm:** bên gọi pre-check tracker + `Ticket:` một lần đầu pipeline; tắt → không invoke skill lần nào (trước đây invoke ở mỗi mốc chỉ để no-op, mỗi lần nạp lại ~10KB). Bật → invoke một lần, các mốc sau làm theo body đã có trong context. Quy ước nằm trong `skills/tracking/SKILL.md` (vẫn là nơi duy nhất chứa logic sync).
- **Tách template ra file riêng, chỉ Read khi tới bước ghi:** `skills/deliver-story/templates/{report,execution-report}.md`, `skills/deliver-task/templates/report.md`, `skills/spec/templates/{requirement,request}.md`. Nội dung template không đổi.
- **Mọi agent trả lời cuối gọn khi pipeline gọi:** chỉ block JSON theo contract + 3–5 dòng tóm tắt; chi tiết nằm trong file artifact. `qc-executor` không in QC report văn xuôi trong pipeline (orchestrator tự ghi execution report từ JSON). Contract JSON không đổi.
- **Rút gọn `description` của 12 agent và 6 skill** (bỏ few-shot `<example>`, ~25KB → ~6KB) — phần này được nạp vào mọi session có cài plugin.

## [0.9.1] — 2026-11-09

### Changed

- **Giảm chi phí model** (bước đầu tối ưu token): `dev-leader` `fable` → `opus` (chỉ còn `architect` dùng `fable`); `qc-designer` và `bug-triage` `opus` → `sonnet`. Routing Codex (`.codex-plugin/agent-models.toml`) không đổi.
- **Rút gọn prompt `dev-backend`/`dev-frontend` (~50% body)**: bỏ phần lời khuyên chung chung mà model vốn đã làm, gom các ràng buộc cứng (migration/lockstep/cache/scope) thành một mục; bỏ ví dụ stack cụ thể (Inertia) để giữ stack-agnostic. Hợp đồng JSON `{ status, filesChanged, summary, followUps }` giữ nguyên. Thêm: khi chạy trong pipeline (`deliver-story`/`deliver-task`) chỉ trả JSON + tối đa 3 dòng tóm tắt, và không hỏi lại user mà báo `partial`/`skipped` kèm lý do.

## [0.9.0] — 2026-10-19

### Changed

- **`/spec` hỏi trực tiếp, tập trung vào chức năng**: bỏ phỏng vấn 7 phase (why-now, persona, JTBD, metric, rủi ro dự án). Claude tự suy từ mô tả + codebase trước, rồi hỏi bằng `AskUserQuestion` — mỗi câu là một quyết định cụ thể có đáp án đề xuất sẵn, người dùng chỉ cần bấm chọn (không in danh sách câu hỏi ra chat). Tối đa 5 lần hỏi (mỗi lần ≤4 câu, đủ rõ thì dừng sớm), cuối cùng một câu xác nhận với bản tóm tắt trong preview. Môi trường không có `AskUserQuestion` → hỏi từng câu một trong chat.
- Template `requirement.md` chuyển sang hướng chức năng (Users & Roles, Functional requirements: luồng/dữ liệu/quy tắc/trường hợp biên, Acceptance) — giữ đánh số mục 1–7 và trường `Ticket:`; `architect` cập nhật danh sách mục đọc cho khớp.

## [0.8.0] — 2026-09-23

### Added

- **`/spec` phân loại STORY vs TASK trước khi phỏng vấn** (tiết kiệm token): STORY → phỏng vấn 7 phase như cũ → `.claude/stories/{id}/requirement.md`; TASK (feat/fixbug nhỏ) → một lượt hỏi gọn → `.claude/tasks/{taskid}/request.md` (`taskid` = ID ticket hoặc local `T-{NNN}`).
- **`/deliver` tự định tuyến theo id**: story → architect → [GATE ADR] → `deliver-auto`; task → `task-planner` → [GATE duyệt plan trong chat] → `deliver-task`.
- `tracking` (`kind=task`) đọc `Ticket:` từ `request.md` nếu có (`—` = no-op); `tracking-poll` bỏ qua task local và xử task do `/spec` tạo (chỉ có `request.md`) như ticket mới.
- `/deliver` luồng TASK ghi `claim.md` nguồn `/deliver`; `tracking-poll` Bước R bỏ qua các task này để không resume/build trùng với phiên tay. Người kéo thẻ về Todo → poll re-claim và nhận lại quyền điều khiển.

### Changed

- **Đổi tên skill `deliver-light` → `deliver-task`** (khớp khái niệm "task" của luồng nhẹ). Mọi tham chiếu trong skill/command/agent/docs đã cập nhật; lời gọi cũ `deliver-light` không còn.
- **Đổi tên skill `deliver-auto` → `deliver-story`** (đối xứng với `deliver-task`: `/deliver` định tuyến story → `deliver-story`, task → `deliver-task`). Mọi tham chiếu (skill/command/agent/docs/sơ đồ SVG) đã cập nhật; lời gọi cũ `deliver-auto` không còn.

## [0.7.0] — 2026-07-29

### Added

- **Fixbug intake từ log production** — bước triage đứng TRƯỚC luồng board nhẹ, biến log lỗi thành task fixbug tự động:
  - **Command mới `/msdlc:log-triage`** (`commands/log-triage.md`): nhận log dán trực tiếp hoặc đường dẫn file → gọi agent phân loại → **tạo ticket Bug ở cột intake (Todo)** trên board để `/msdlc:tracking-poll` nhặt và fix. **Bỏ qua noise** (không phải bug) và **bỏ qua bug đã có ticket** (khử trùng idempotent). One-shot, lặp được qua `/loop`/`schedule` nếu trỏ vào file log cố định.
  - **Agent mới `bug-triage`** (`agents/bug-triage.md`, `opus`, `memory: local`): gom log rời rạc thành các **loại bug riêng biệt** (một lỗi lặp N lần = một bug), **đối chiếu codebase** để lọc bug thật vs noise (timeout third-party, config sai môi trường, health-check, 4xx mong đợi…), và sinh **`signatureBasis` ổn định** làm khóa khử trùng. Không viết code, không đụng MCP — chỉ trả JSON `{ bugs[], discarded[] }`. Học pattern noise tái diễn qua memory.
  - **Khử trùng 2 lớp, board là nguồn sự thật**: ledger cục bộ `.claude/bug-triage/ledger.md` (cache) + marker `[bug-sig:<hash>]` nhúng trong description ticket (quyết định). Ticket đã Done → cho phép tạo lại nếu lỗi tái diễn.
  - **Giữ nguyên gate**: log-triage CHỈ đổ ticket vào cột intake — không tự build, không tự Validate/Approved/Done. Cổng duyệt vẫn ở `tracking-poll` (comment plan → Validate → người kéo Approved mới build).
  - **Điền đủ field bắt buộc của tracker**: trước khi tạo, dò danh sách field `required` của issue type Bug từ chính tracker (Jira `getJiraProjectIssueTypesMetadata`/`getJiraIssueTypeMetaWithFields`; Notion đọc schema property) rồi điền đầy đủ — map từ dữ liệu bug khi được, còn lại dùng mặc định hợp lý hoặc hỏi user một lần/lượt. Không suy được khi chạy nền → bỏ qua bug đó + log rõ, không tạo ticket lỗi. Assignee để trống (Unassigned).
  - **Không hardcode, no-op khi thiếu tracker**: đọc connector + project + cột intake từ `## Task tracker` trong `.claude/profile.md` (không thêm section profile mới); chưa cấu hình tracker → báo chạy `/msdlc:init` rồi dừng. Issue type mặc định `Bug`, label `from-log`.
  - `init` gợi ý thêm `.claude/bug-triage/` vào `.gitignore` (ledger là cache cục bộ per-máy).

## [0.6.3] — 2026-07-28

### Added

- **Pull đúng nhánh TRƯỚC khi phân tích (luồng board)**: thêm op **`sync`** cho skill `msdlc:git-flow` (`{taskid} sync`) và gọi nó trong `/msdlc:tracking-poll` ngay trước mỗi lần `task-planner` chạy (Bước 1 phân tích lần đầu, Bước 1b revision/reopen, Bước R resume phân tích). Trước đây git chỉ `checkout base + pull` ở lúc build (op `start`, Bước 2) → `task-planner` phân tích trên nhánh đang checkout bất kỳ (cũ/sai). Nay:
  - Task **chưa có nhánh riêng** → pull **nhánh base** (theo profile `## Git → Base branch`, không hardcode `master`; trống → auto-detect default branch).
  - Task **đã có nhánh riêng** (từng build, thường đang reopen/revision — "task bị sai cần thảo luận lại") → pull **chính nhánh task đó**.
  - `sync` **KHÔNG tạo nhánh** (nhánh task vẫn chỉ tạo sau khi duyệt ở op `start`); thứ tự luồng board: `sync` → `start` → `finish`.
- **Làm lần lượt từng task (chống pull chồng chéo)**: `sync`/`start`/`finish` best-effort — git đang bận (`index.lock`) hoặc working tree bẩn → bỏ switch, phân tích trên nhánh hiện tại, **không crash lượt**. Dựa vào `index.lock` của git để serialize các lượt poll gối đầu; **không thêm lockfile riêng, không stale-lock**. No-op khi tắt git flow (không regression).

## [0.6.2] — 2026-07-23

### Fixed

- **Ticket đã build kéo về Todo bị "idempotent skip", không đọc comment** (0.6.1 chưa đủ): Bước R skip theo sự tồn tại `report.md` mà KHÔNG xét cột hiện tại → ticket đang ở Todo (người mở lại) bị bỏ qua trước khi tới bước đọc comment; và nhánh revision coi "không thấy comment mới = skip". Nay áp dụng nguyên tắc **cột board là nguồn sự thật**:
  - **Bước R rẽ nhánh theo CỘT trước**: ticket đang ở intake (Todo) → KHÔNG xử ở Bước R, để Bước 1b lo (kể cả đã có `plan.md`/`report.md`). Nhánh "report.md → done → skip" chỉ áp dụng khi ticket ở `Review`/`Done`.
  - **Bước 1b = REOPEN**: ticket có dir mà lại ở Todo → **luôn** xử lý (không skip dù có `plan.md`/`report.md`, **không cần** comment mới — kéo về Todo đã là tín hiệu). **Đọc comment BẮT BUỘC**; nếu đã có `report.md` (làm lại) → archive `report.md` → `report.prev-<ngày>.md` để build lại sau khi duyệt.
  - **Đọc comment là bắt buộc** ở nhánh reopen (1b) và duyệt (Bước 2); ghi rõ lý do khi skip bất kỳ ticket nào.
- **`tracking-poll` `allowed-tools` thiếu MCP** → không fetch được cột/comment: thêm wildcard MCP của các connector (Atlassian/Asana/Linear/monday/Notion) + `Bash` (cho git-flow). Dự án dùng MCP server tên khác → thêm vào allowed-tools.

### Added

- **Hỗ trợ Notion làm tracker**: thêm connector `Notion` vào `tracking` + `allowed-tools` của poll (`mcp__claude_ai_Notion__*`). Notion là database chứ không phải kanban Jira → tài liệu hoá ánh xạ: "cột" = option property Status/Select; "chuyển cột" = `notion-update-page`; đọc/ghi comment = `notion-get-comments`/`notion-create-comment`; board key = database ID, ticket id = page ID. Cập nhật `profile.template` + `init` (Bước 2c).

## [0.6.1] — 2026-07-23

### Fixed

- **Poll bỏ qua yêu cầu sửa plan khi kéo ticket về Todo**: ticket đã có `.claude/tasks/{taskid}/` bị kéo ngược về Todo (kèm comment góp ý) trước đây bị skip → plan không bao giờ được cập nhật. Nay Bước 1 tách nhánh **1b (revision)**: re-claim → đọc comment người → `task-planner` **chế độ cập nhật** sửa `plan.md` → comment bản mới → Validate chờ duyệt lại (vòng revision không giới hạn).
- **Poll bỏ qua câu trả lời Open questions khi duyệt**: Bước 2 trước đây build thẳng từ `plan.md`, không đọc comment ticket → câu trả lời cho Open questions bị mất. Nay Bước 2 fetch comment ticket, có comment người mới sau plan → `task-planner` fold câu trả lời vào `plan.md` (resolve Open questions) rồi mới build (không quay lại Validate — kéo sang Approved đã là duyệt). Còn Open question chặn chưa trả lời → ghi rõ + build phần đã rõ, không bịa.

### Changed

- **`task-planner`**: thêm **chế độ cập nhật (revision)** — nhận `plan.md` cũ + comment feedback/câu trả lời do caller truyền (agent không tự đọc ticket), giữ phần còn đúng, fold feedback, resolve Open questions đã trả lời, đánh dấu header `> Cập nhật: … · revision N`.
- **`tracking`**: comment `validate` (kind=task) thêm dòng hướng dẫn workflow (sửa plan = kéo về Todo; duyệt = trả lời Open question rồi kéo Approved).
- README: mô tả vòng sửa plan + trả lời qua comment.

## [0.6.0] — 2026-07-22

### Added

- **Git flow cho luồng board (opt-in)**: `/msdlc:tracking-poll` giờ có thể tách một nhánh riêng cho mỗi task từ base branch, build xong tự commit → push → tạo merge/pull request → comment link MR vào ticket.
  - **Skill mới `msdlc:git-flow`** (`{taskid} start|finish`): nơi duy nhất chứa logic git. `start` tạo/switch nhánh `<type>/<taskid>-<slug>` off base (type theo `msdlc:commit`, slug từ title ticket); `finish` một commit qua `msdlc:commit` + push + tạo MR (auto qua `gh`/`glab` nếu có + auth, không thì fallback dựng link "create MR" điền sẵn từ remote URL) + ghi `> MR:` vào report. Tự **no-op** khi cờ tắt / không phải git repo. **Máy không bao giờ tự merge** — merge là quyền người (đối xứng never-auto-Done).
  - **Mục `## Git` trong `profile.md`**: cờ bật (mặc định `no`), base branch (trống→auto-detect default branch), branch pattern, MR tool (trống→suy từ remote), MR target.
- `init.md`: thêm Bước 2d hỏi & điền mục `## Git` khi dự án là git repo + dùng poll.

### Changed

- **`tracking-poll`**: khi git flow bật → Bước 2 chèn `git-flow start` TRƯỚC build và `git-flow finish` SAU build; chỉ **một build/lượt** (không juggle nhiều nhánh trên working tree chung); Bước R resume thêm nhánh finish dở (report có nhưng thiếu `> MR:`). Không bao giờ build trên base (start fail → skip ticket, không clobber). Tắt cờ → hành vi 0.5.0 y nguyên.
- **`tracking`**: comment mốc `review` nếu report có dòng `> MR:`/`> PR:` → đính kèm link MR + nhắc review-rồi-merge (không đổi contract).
- `deliver-light`: report template chừa chỗ cho dòng `> MR:` (do `git-flow finish` điền); deliver-light vẫn KHÔNG tự commit (commit do git-flow qua `msdlc:commit`).
- README: thêm skill `git-flow`, cập nhật sequence poll + section board (git flow, một build/lượt, không tự merge), glossary.

## [0.5.0] — 2026-07-22

### Changed

- **Thiết kế lại luồng đồng bộ board ngoài sang LUỒNG NHẸ** (task board chỉ là feat/fixbug nhỏ, không hợp nghi thức spec+ADR+QC map/reduce). `/msdlc:tracking-poll` giờ:
  - **Nhận ticket bằng claim/lock**: chuyển `Todo → planning` TRƯỚC khi phân tích (ticket rời cột intake nên session khác không nhận trùng; ghi `claim.md` local chống overlap cùng máy).
  - Chạy agent nhẹ `task-planner` (thay `architect`) dò codebase → ghi `.claude/tasks/{taskid}/plan.md` + comment **plan chi tiết** vào ticket cho user duyệt → đẩy `Validate` rồi dừng.
  - Ticket đã `Approved` (người kéo = duyệt plan) → chuyển `in-progress` TRƯỚC → build gọn bằng `deliver-light` → `Review`.
  - Thêm **bước resume** đầu mỗi lượt: nhặt lại task kẹt ở `planning`/`in-progress` do lượt trước fail (dựa trên cột board + tồn tại `plan.md`/`report.md`).
  - Luồng thủ công `/spec`+`/deliver`+`deliver-auto` (dùng `.claude/stories/` + ADR) **giữ nguyên**, không đụng.

### Added

- **Agent `task-planner`**: phân tích task nhỏ từ board dựa trên codebase, ghi `plan.md` (phương án + subtask file-disjoint có `touchesFiles`/`dependsOn` + files đụng + acceptance). Không tạo ADR/docs, không viết code — bản nhẹ của `architect`.
- **Skill `deliver-light`**: build gọn từ `plan.md` — implement song song theo subtask file-disjoint (dev-backend/dev-frontend) → reviewer (≤1 vòng) → qc-executor + security-auditor song song (≤2 vòng) → chronicler → `report.md`. Không vỡ task bằng `dev-leader`, không QC map/reduce. KHÔNG tự gọi `tracking` (poll lo transition).
- **Convention `.claude/tasks/{taskid}/`** cho luồng board (`taskid` = ID ticket), tách khỏi `.claude/stories/{id}/` của luồng thủ công.

### Changed (tiếp)

- **`tracking` thêm tham số thứ ba `kind`** ∈ `story` (mặc định) \| `task`. Lời gọi 2 tham số cũ hành xử y hệt (backward-compat). `kind=task`: `{id}` chính là ID ticket (không đọc `requirement.md`); comment ở `validate` là plan chi tiết từ `tasks/{id}/plan.md`, ở `review` từ `tasks/{id}/report.md`. Cột `planning` giờ là bước claim/lock → khuyến nghị override tên cột trong profile.
- `profile.template.md`: thêm đường dẫn `.claude/tasks/{taskid}/` + `plan.md`; ghi chú poll dùng luồng nhẹ và cột `planning` là claim/lock.
- `README.md`: cập nhật bảng Agents/Skills, sơ đồ + sequence "Đồng bộ board ngoài" theo luồng nhẹ; thêm `.claude/stories/`+`.claude/tasks/` vào gợi ý `.gitignore`; phân biệt thuật ngữ `story` (thủ công) vs `task (board)`.

## [0.4.0] — 2026-07-09

### Fixed

- **Đóng lỗ gate ADR**: trạng thái duyệt giờ được persist bằng header `Status: Accepted` trong `adr.md` — `/deliver` ghi khi user duyệt (kể cả nhánh "build luôn từ ADR có sẵn", nay BẮT BUỘC xác nhận), `tracking-poll` ghi khi người kéo ticket sang Approved; `deliver-auto` từ chối chạy nếu ADR còn `Proposed` (ADR cũ không có `Status:` → hỏi xác nhận một lần, backward compat).
- **`tracking-poll` idempotency**: story gắn ticket nhưng thiếu `adr.md` (architect fail lượt trước) → resume trên story cũ thay vì cấp id mới (hết tạo story trùng); thêm nhánh xử lý khi `deliver-auto` fail giữa chừng.
- **`security-auditor` có JSON contract pipeline**: mục "Pipeline Output" mới — bắt buộc ghi report vào `security/` và trả `{ findings: [{severity,title,file,line,remediation,ruleId}] }` đúng schema orchestrator parse (trước đây thiếu hẳn).
- `/msdlc:init` không còn ghi đè `agent-memory.md` vô điều kiện — thêm guard no-overwrite như profile/rules.
- Mô tả skill `spec` sửa `spec.md` → `requirement.md` (tên artifact thật); typo `Planing`/`InProgess` trong README + profile template; hướng dẫn cài thủ công bỏ lệnh `claude plugin path` không tồn tại.

### Changed

- **Curate lại `tools` các agent**: dev-backend/dev-frontend/dev-leader/qc-designer thêm `Grep`/`Glob` (prompt yêu cầu dò codebase mà thiếu tool), bỏ NotebookEdit/Task*/MCP/Web thừa; qc-executor bỏ `Edit`/`NotebookEdit` (khớp boundary "không tự sửa code"); security-auditor bỏ Task*/MCP.
- `architect` có memory footer (trước khai `memory: local` mà không có giao thức → memory chết); quy ước diagram đọc từ profile (mục mới `## Quy ước diagram`), fallback mặc định PlantUML + `docs/diagrams/` như cũ.
- `deliver-auto`: nguyên tắc xử lý JSON contract hỏng (retry 1 lần → fallback đọc artifact → dừng có báo); phát hiện cycle `dependsOn` → liệt kê task kẹt + abort pipeline (không QC trên code dở); reviewer/security-auditor nhận scope theo `filesChanged` gom từ các wave (tránh nhiễu working tree); frontmatter mô tả đủ qc-leader map/reduce + reviewer.
- `tracking`: lỗi transition/comment sau guard (MCP rớt giữa chừng) là non-fatal — log một dòng, không làm dừng pipeline.
- `dev-leader`: quy tắc routing rõ cho task `docs`/`cross-cutting` (docs-only không sinh task — chronicler lo; cross-cutting gán theo domain sở hữu đa số `touchesFiles`).
- Lời văn memory footer: "thư mục đã tồn tại" → "Write tự tạo thư mục nếu chưa có" (init không tạo sẵn thư mục memory); qc-executor gộp double memory section.
- Profile template: thêm dòng `todo →` vào mapping cột (kèm ghi chú trùng cột intake); `/msdlc:init` nhận diện thêm C#/.NET (`*.csproj`/`*.sln`) và Ruby (`Gemfile`).
- `plugin.json`: bump 0.4.0, thêm `"license": "MIT"`.
- docs: README chuyển sơ đồ ASCII sang **Mermaid** (GitHub render trực tiếp) — pipeline end-to-end, bên trong deliver-auto (Phase 1→5), cột board 🤖/👤, sequence vòng poll; thêm section **"Các workflow áp dụng"** với sơ đồ chọn workflow theo thứ đang có + 5 công thức dùng (trọn gói / từ requirement / từ ADR / gọi lẻ agent / vận hành theo board).

## [0.3.0] — 2026-07-02

### Added

- Skill mới **`msdlc:tracking {id} {phase}`** — đồng bộ trạng thái story sang cột board ngoài (Jira/Asana/Linear/Monday) tại các mốc `todo/planning/validate/approved/in-progress/review`. Gom **toàn bộ** logic tracker vào một chỗ. **Opt-in**: không cấu hình `## Task tracker` trong `profile.md` hoặc story không gắn `Ticket:` → skill tự **no-op**, pipeline chạy thuần local như cũ. **Không bao giờ tự chuyển Done.**
- Command mới **`/msdlc:tracking-poll`** — quét board **một lượt** (idempotent): ticket ở cột intake → tạo story + `architect` + đẩy sang `Validate` rồi **dừng**; ticket ở cột `Approved` (do người kéo) → tự `deliver-auto` build → `Review`. Lặp giao cho harness (`/loop` hoặc `schedule`); msdlc không tự chế scheduling. Bật qua cờ `poll` trong profile (mặc định tắt).
- `profile.template.md` thêm mục `## Task tracker` (tool + connector MCP, project key, override tên cột từng mốc, cột intake/build-trigger, cờ poll).
- `requirement.md` thêm trường header `Ticket:` để liên kết story ↔ ticket board.

### Changed

- **Giữ đúng một cổng duyệt** khi dùng board: cột board CHÍNH LÀ gate — poll dừng ở `Validate`, chỉ ticket người kéo sang `Approved` mới được tự build. Máy không bao giờ tự vượt gate; sync chỉ là side-effect, không phải gate mới.
- `spec`/`deliver`/`deliver-auto` thêm lời gọi `msdlc:tracking` một dòng tại mỗi mốc (tự no-op khi không có tracker) — không rải logic tracker vào các skill này.
- `/msdlc:init` thêm **Bước 2c — Dò tracker**: phát hiện connector MCP đang connect, hỏi user điền mục `## Task tracker` (opt-in, không bịa tên cột).
- `.claude-plugin/marketplace.json` (source `.`) để repo cài trực tiếp qua `github:minhhv08/msdlc`.
- docs: README thêm section "Đồng bộ board ngoài" + sơ đồ flow board + hướng dẫn loop; bảng thuật ngữ thêm `tracker sync`/`poll`.

## [0.2.0] — 2026-07-01

### Added

- Agent mới **`qc-leader`** điều phối thiết kế test theo **map/reduce**: chế độ *enumerate* (liệt kê test-case stub + đề xuất bucket cân bằng + coverage) và *merge* (gộp các part thành Traceability Matrix + Coverage & Gaps ở `tests/README.md`).
- `qc-designer` thêm chế độ **design-subset**: nhận danh sách stub + file output riêng, flesh-out đặc tả đầy đủ, giữ nguyên `id`/`source`. Chế độ *full* (gọi lẻ) giữ nguyên — backward-compatible.
- Cơ chế **per-project rules** `.claude/rules/` (scope: `global`/`backend`/`frontend`/`security`/`testing`); mỗi rule có `id` + `severity` (`MUST`/`SHOULD`). Template trong `shared/rules/`.
- `reviewer` enforce rule: vi phạm `MUST` → blocking, `SHOULD` → suggestion; finding mang `ruleId`.
- `security-auditor` enforce `R-SEC-*`: vi phạm `MUST` được nâng severity tối thiểu `High`; finding mang `ruleId`.
- `/msdlc:init` copy `shared/rules/` (no-overwrite) + auto-seed rule từ CLAUDE.md/CONTRIBUTING/.editorconfig/linter, đánh dấu `<!-- seeded từ <nguồn>, cần xác nhận -->`.

### Changed

- **Song song hoá thiết kế test:** `qc-leader` (enumerate) chạy **song song với `dev-leader` ở Phase 1**; sang Phase 2 fan-out **N `qc-designer` (design-subset)** theo bucket ngay từ Wave 1 (mỗi bucket → `tests/testcases-part-{k}.md`), rồi `qc-leader` (merge) gộp — thay vì một `qc-designer` đơn — cắt đường găng của Phase 3. Story nhỏ → 1 bucket, không fan-out thừa.
- **Đổi tên agent `planner` → `dev-leader`** cho đối xứng với `qc-leader` (dev-leader vỡ ADR→task, qc-leader vỡ requirement/ADR→test). Cập nhật mọi tham chiếu trong skills, README, rules, init, manifest và contracts. Contract task giữ nguyên (chỉ đổi tên).
  - **Migration cho project đang dùng plugin:** nếu có memory cũ `.claude/agent-memory-local/planner/`, đổi tên thủ công thành `.claude/agent-memory-local/dev-leader/` để giữ lại institutional memory (không tự động xử lý).
- Mọi agent đọc thêm `.claude/rules/` đúng scope; `chronicler` nay cũng đọc profile + rules. Thiếu rules → giữ hành vi cũ (không regression).
- Quy tắc commit chuyển từ `profile.md` sang `.claude/rules/global.md` nhóm `## Commit`; skill `commit` ưu tiên rule của dự án, fallback về định dạng msdlc.
- Đổi tên skill `auto-deliver` → `deliver-auto` (gom cạnh `deliver` khi sắp xếp); cập nhật mọi tham chiếu trong `skills/deliver`, docs và prompt agent.
- fix: tách `dev-leader` ra Phase 1 riêng, `qc-designer` chạy song song với Wave 1 dev thay vì block dev agents.
- docs: cập nhật README — thành phần tách theo loại, bảng thuật ngữ, section hooks.

## [0.1.0] — 2025-06-22

### Added
- `hooks/block-read-secrets.sh` — chặn đọc file secrets/credentials qua Read tool
- `hooks/block-bash-dangerous.sh` — chặn lệnh Bash nguy hiểm (rm -rf hệ thống, pipe-to-shell, force-push main, DROP DATABASE…)
- Đăng ký hooks vào `plugin.json` (PreToolUse: Read + Bash)
- `agents/reviewer` — review code 6 chiều, auto-fix ≤1 vòng trước QC
- `skills/commit` — quy ước commit `(type): description` + Co-Authored-By AI
- Ghi `report.md` tổng hợp cuối pipeline vào `.claude/stories/{id}/`
- Ghi execution report `tests/{project}-execution-attempt-{N}.md` sau mỗi lần qc-executor chạy
- Ghi `## Result` vào task file sau khi dev agent hoàn thành
- Song song hoá dev tasks và qc-executor theo project scope

### Changed
- Chuẩn hoá quy ước commit toàn plugin (bỏ hướng dẫn commit khỏi từng agent, dồn vào skill commit)
- Chuẩn hoá section `Pipeline Output` cho tất cả agent

## [0.0.1] — 2025-06-17

### Added
- Khởi tạo plugin: `architect`, `planner`, `dev-backend`, `dev-frontend`, `qc-designer`, `qc-executor`, `security-auditor`, `chronicler`
- Skills: `spec`, `deliver`, `auto-deliver`
- Command: `init`
- `shared/agent-memory.md`, `shared/profile.template.md`
- `plugin.json` manifest
