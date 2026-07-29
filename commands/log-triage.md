---
description: Đọc log lỗi production → gom thành các loại bug (đối chiếu codebase) → tạo task Bug ở cột Todo trên board để luồng fixbug xử lý. Bỏ qua log không phải bug, và bỏ qua bug đã có ticket. Nhận log dán trực tiếp hoặc đường dẫn file. Chạy một lượt; lặp được bằng /loop nếu trỏ vào một file log cố định.
allowed-tools: Read, Write, Glob, Grep, Task, Skill, mcp__claude_ai_Atlassian__*, mcp__claude_ai_Asana__*, mcp__claude_ai_Linear__*, mcp__claude_ai_monday_com__*, mcp__claude_ai_Notion__*
# Cần MCP tool của tracker (Jira/Asana/Linear/Monday/Notion) để: (1) tìm ticket đã có → tránh tạo trùng, (2) tạo ticket mới.
# Dự án dùng MCP server tên khác → thêm tool của nó vào dòng allowed-tools ở trên.
# Riêng Notion: "cột" = giá trị property Status của page; tạo ticket = tạo page (notion-create-pages); "board key" = database ID.
---

# /msdlc:log-triage — Biến log lỗi thành task fixbug

Đây là **bước đầu tiên của luồng fixbug**: đọc log lỗi production, tổng hợp thành các **loại bug**, và tạo mỗi loại bug thành **một ticket ở cột Todo** trên board. Từ cột Todo, luồng board sẵn có (`/msdlc:tracking-poll` → `task-planner` → `deliver-light`) sẽ tự phân tích và sửa.

Lệnh chạy **một lượt rồi dừng**. Muốn chạy định kỳ thì để harness lo: `/loop <thời gian> /msdlc:log-triage <đường dẫn log>` hoặc `schedule`. Không tự viết vòng lặp trong này.

## Lệnh này LÀM gì và KHÔNG làm gì

- ✅ **Làm:** phân loại log → tạo ticket Bug ở cột Todo.
- ❌ **Không làm:** không tự sửa code, không tự chuyển ticket sang Validate/Approved/Done, không build. Đây chỉ là bước "đổ việc vào Todo".
- **Ai làm gì:** Agent `bug-triage` lo việc *phân loại bug* (nó đọc codebase). Còn *tạo ticket* và *chống trùng* là do lệnh này (main agent) tự làm qua MCP.

## Ba quy tắc lọc (đúng yêu cầu người dùng)

1. **Không phải bug → bỏ.** Log kiểu timeout mạng tạm thời, gọi third-party lỗi, config sai môi trường, health-check… không phải bug code → không tạo ticket.
2. **Bug đã có ticket → bỏ.** Một bug được coi là "đã liệt kê" nếu trên board **đang có ticket mở** mang cùng chữ ký `[bug-sig:<hash>]`. Không tạo ticket thứ hai cho cùng một lỗi.
3. **Còn lại (bug thật, chưa có ticket) → tạo ticket Todo.**

> **Board là nguồn sự thật để chống trùng.** File ledger cục bộ chỉ là bộ nhớ đệm cho nhanh. Nếu ticket cũ đã Done/Closed mà lỗi tái diễn → cho phép tạo ticket mới.

## Các bước

### Bước 0 — Kiểm tra cấu hình

1. Đọc mục `## Task tracker` trong `.claude/profile.md`.
   - Chưa cấu hình (thiếu tool hoặc project) → báo: *"Chưa cấu hình tracker trong profile — không có nơi tạo ticket. Chạy `/msdlc:init` để cấu hình."* rồi **dừng**.
2. Lấy từ profile: connector MCP (Jira→`Atlassian`, Asana→`Asana`, Linear→`Linear`, Monday→`monday`, Notion→`Notion`), project/board key, và **tên cột Todo** (ánh xạ `todo` trong `## Task tracker` — ticket mới phải nằm đúng cột này thì `tracking-poll` mới nhặt được; cách suy tên cột giống skill `msdlc:tracking`).
   - Connector chưa kết nối → báo và **dừng** (không hỏi token/OAuth).
3. **Mặc định, không cần cấu hình thêm:** issue type = `Bug`, label = `from-log`. Nếu board không có issue type `Bug` → dùng type mặc định của project hoặc hỏi người dùng một lần, không tự bịa.
4. **Dò field BẮT BUỘC của tracker** cho issue type sẽ tạo (đúng tinh thần "hỏi chính tool, không đoán schema"):
   - Jira: gọi `getJiraProjectIssueTypesMetadata` / `getJiraIssueTypeMetaWithFields` để lấy danh sách field và cờ `required`.
   - Notion: đọc schema các property của database (property nào bắt buộc).
   - Ghi nhớ danh sách field required + field-cho-phép để Bước 4 điền đủ, tránh tạo ticket bị fail vì thiếu field.

### Bước 1 — Lấy log

Đọc log từ **tham số của lệnh**:
- Tham số là **đường dẫn file/thư mục** có thật → `Read` nội dung (nhiều file → đọc lần lượt, ưu tiên file error/exception).
- Tham số là **đoạn log dán trực tiếp** → dùng luôn.
- **Không có tham số** → hỏi người dùng dán log hoặc đưa đường dẫn. Không tự bịa log.

Log quá dài → ưu tiên các dòng ERROR/FATAL/exception/stack trace, nhưng giữ đủ ngữ cảnh quanh mỗi lỗi để agent gom nhóm được (đừng cắt cụt làm mất manh mối).

### Bước 2 — Phân loại bằng agent bug-triage

Gọi **Agent `bug-triage`** (qua Task tool), đưa cho nó **log** (hoặc đường dẫn file) + gợi ý project nếu biết. Agent đọc codebase và trả về JSON:

```json
{ "bugs": [ { "signatureBasis": "...", "title": "...", "type": "...", "severity": "...",
             "evidence": "...", "suspectedFiles": ["..."], "rootCauseHint": "..." } ],
  "discarded": [ { "reason": "...", "sample": "..." } ] }
```

`bugs` rỗng (không có bug thật) → sang Bước 5 báo cáo và dừng.

### Bước 3 — Chống trùng (2 lớp, board quyết định)

Với **mỗi** bug trong `bugs`: tạo chữ ký `sig` = hash ngắn của `signatureBasis` (chuẩn hoá: chữ thường, bỏ khoảng trắng thừa; ví dụ 8–12 ký tự hex). Rồi kiểm tra theo thứ tự:

1. **Ledger cục bộ** `.claude/bug-triage/ledger.md` (bảng `sig | ticketId | ngày | title`): nếu `sig` đã có → **bỏ qua**, ghi log *"đã có ticket {ticketId} (ledger)"*. Chưa có file ledger → coi như trống.
2. **Trên board** (đây mới là quyết định cuối): tìm các ticket **đang mở** (chưa Done/Closed) trong project — lọc theo label `from-log` nếu board hỗ trợ — rồi soi chuỗi `[bug-sig:<sig>]` trong phần mô tả.
   - Tìm thấy → **bỏ qua**, cập nhật ledger (để lần sau nhanh), ghi log *"đã có ticket {ticketId} (board)"*.
   - Không thấy theo marker → so thêm title + top frame cho chắc; nếu nghi trùng → **bỏ qua và ghi log để người kiểm** (thà bỏ sót còn hơn tạo trùng liều).

Nếu query board bị lỗi (MCP fail) → **không dừng cả lượt**: ghi cảnh báo *"không kiểm tra được trùng trên board, chỉ dựa ledger"* rồi đi tiếp. (Ledger đã có `sig` thì vẫn bỏ qua như thường.)

### Bước 4 — Tạo ticket Todo

Với mỗi bug **còn lại sau khi lọc trùng**, tạo một ticket qua MCP:
- **Nơi tạo:** project/board theo profile; issue type `Bug`; **status = cột Todo**. Nếu API không đặt được status Todo lúc tạo → tạo xong rồi chuyển ticket về cột Todo (đừng để nó rơi vào cột khác).
- **Tiêu đề:** `[Claude] <title>` (giữ tiền tố `[Claude]` như các comment khác của msdlc).
- **Mô tả** (viết như một bug report gọn để `task-planner` đọc mà lập plan):
  - **Triệu chứng** + độ nghiêm trọng (`severity`) + loại (`type`).
  - **Bằng chứng:** trích `evidence` (stack trace/log tiêu biểu, số lần xuất hiện nếu có).
  - **File nghi ngờ:** `suspectedFiles`.
  - **Gợi ý nguyên nhân:** `rootCauseHint`.
  - **Dòng cuối (khoá chống trùng, giữ đúng định dạng):** `[bug-sig:<sig>] [from-log]`.
- **Nhãn:** gắn `from-log` nếu board hỗ trợ.
- **Field bắt buộc của tracker (đã dò ở Bước 0):** điền **đầy đủ** mọi field mà tracker đánh dấu `required` cho issue type Bug — nếu không, API tạo ticket sẽ fail hoặc ticket thiếu thông tin. Cách lấy giá trị:
  - Map được từ dữ liệu bug thì dùng luôn: `summary/title ← title`, `description ← mô tả ở trên`, `issue type ← Bug`.
  - Field required còn lại (vd Reporter mặc định, hoặc field custom của project) → dùng **giá trị mặc định hợp lý** của project (giá trị đầu tiên hợp lệ mà tracker cho phép); nếu không có mặc định an toàn → **hỏi người dùng một lần** rồi **áp cho mọi bug còn lại trong lượt** (đừng hỏi lặp lại từng bug).
  - Chạy không có người (loop/schedule) mà một field required không suy được → **bỏ qua bug đó + ghi log rõ field nào thiếu** (để lần sau xử), KHÔNG tạo ticket lỗi, KHÔNG làm crash lượt.
- **Assignee:** để trống (Unassigned) — team tự nhận trên board.
- Tạo xong → ghi một dòng vào `.claude/bug-triage/ledger.md`: `<sig> | <ticketId> | <ngày> | <title>`.

Tạo một ticket bị lỗi → **không dừng lượt**: ghi log rồi làm tiếp bug kế. Không sửa code, không đụng ticket ở cột khác cột Todo.

> **Notion:** tạo page bằng `notion-create-pages` trong database (board key), đặt property Status = giá trị Todo, đưa nội dung bug report vào body, và **vẫn nhúng `[bug-sig:<sig>]`** trong body để lần sau chống trùng. "issue type / label" map vào property Select/Tag nếu database có, không có thì bỏ.

### Bước 5 — Tóm tắt

Báo cho người dùng một khối ngắn:
- ✅ Đã tạo **N** ticket: liệt kê `ticketId` + tiêu đề ngắn.
- ⏭️ Bỏ qua **M** bug đã có ticket: `title` + `ticketId` tương ứng.
- 🗑️ Loại **K** nhóm không phải bug: lý do gọn (lấy từ `discarded`).
- Nhắc: *"Các ticket này đang ở cột Todo. Nếu đã bật `/msdlc:tracking-poll`, nó sẽ tự nhặt: phân tích → comment plan → đẩy sang Validate → chờ bạn kéo sang Approved mới build. Chưa bật thì xử lý tay trên board như thường."*

Không có bug thật nào → báo *"Không phát hiện bug cần tạo ticket lượt này."* (kèm số nhóm noise đã loại, nếu có).

## Ghi chú vận hành

- **Chạy lại an toàn (idempotent):** cùng một log chạy nhiều lần cũng không tạo ticket trùng — bug đã có ticket (còn mở trên board / có trong ledger) sẽ bị bỏ qua. Định kỳ: `/loop 30m /msdlc:log-triage /var/log/app/error.log`.
- **Luôn giữ cổng duyệt:** lệnh này chỉ đổ ticket vào cột Todo, không bao giờ tự build/duyệt/đóng. Cổng duyệt nằm ở `tracking-poll` (dừng ở Validate; chỉ build ticket người đã kéo sang Approved).
- **Ledger** `.claude/bug-triage/ledger.md` là bộ nhớ đệm cục bộ trên từng máy → nên cho vào `.gitignore`. Nguồn chống-trùng thật sự là marker `[bug-sig:...]` trên board (xem `/msdlc:init` Bước 3).
- **Nhiều máy cùng triage một board:** tracker không có khoá compare-and-swap, nên khi hai lượt chạy gối đầu vẫn có thể tạo trùng hiếm gặp → nên để **một nguồn triage cho mỗi board**.
