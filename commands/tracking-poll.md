---
description: Quét board ngoài một lượt và tự khởi động pipeline msdlc cho các ticket ở cột intake/Approved — giữ nguyên cổng duyệt (dừng ở Validate; chỉ build ticket đã Approved). Dùng cùng /loop hoặc schedule để chạy định kỳ.
allowed-tools: Read, Write, Glob, Grep, Task, Skill
---

Bạn đang chạy **một lượt poll** của msdlc: quét board ngoài, tự động *khởi động* pipeline cho các ticket đang chờ. Lệnh này chạy **đúng một lượt rồi dừng** — việc lặp là do harness (`/loop <interval> /msdlc:tracking-poll` hoặc `schedule` cron), KHÔNG tự chế vòng lặp ở đây.

**Nguyên tắc cốt lõi — giữ cổng duyệt:** máy KHÔNG BAO GIỜ tự vượt gate ADR. Cột board CHÍNH LÀ cổng: poll đẩy ticket tới `Validate` rồi DỪNG; chỉ ticket đã được **người** kéo sang cột Approved mới được tự build. Không bao giờ tự chuyển Done.

## Bước 0 — Guard

1. Đọc mục `## Task tracker` trong `.claude/profile.md`.
   - Không có mục / chưa điền tool + project → báo *"Chưa cấu hình tracker trong profile — không có gì để poll. Chạy `/msdlc:init` để cấu hình."* và **dừng**.
   - **Cờ bật poll** chưa bật (mặc định tắt) → báo *"Poll đang tắt (opt-in). Bật cờ poll trong `.claude/profile.md` mục Task tracker để dùng."* và **dừng**.
2. Xác định connector MCP + cột intake (vd `Todo`) + cột build-trigger (vd `Approved`) từ profile. Connector chưa connect → báo và dừng (không hỏi token/OAuth).

## Bước 1 — Đoạn 1: intake → Validate (giữ gate, KHÔNG build)

Fetch các ticket ở **cột intake** (theo profile). Với **mỗi** ticket (xử lý tuần tự):

1. **Idempotent check**: nếu đã có story gắn ticket này (tìm trường `Ticket:` trong các `.claude/stories/*/requirement.md`) và story đã có `adr.md` → bỏ qua (đã xử lý), sang ticket kế.
2. Cấp `{id}` mới (số thứ tự kế tiếp, padding 3 chữ số như `/spec`). Tạo `.claude/stories/{id}/requirement.md` **suy từ title + description của ticket**, theo đúng template của `/spec`. Chỗ mơ hồ/thiếu → ghi vào mục **Open questions**, KHÔNG bịa. Ghi header `> Status: Draft · Ngày: <hôm nay> · Người tạo: msdlc:tracking-poll · Ticket: <ID|URL ticket>`.
3. Gọi **Agent `architect`** cho story `{id}` → ghi `.claude/stories/{id}/adr.md` + cập nhật `docs/architecture.md`.
4. Gọi skill **`msdlc:tracking {id} validate`** → đẩy ticket sang `Validate` + comment `[Claude]` link ADR.
5. **DỪNG** với ticket này. **Tuyệt đối không build.** Ticket giờ ở `Validate`, chờ người duyệt (kéo sang `Approved`).

## Bước 2 — Đoạn 2: Approved → build → Review

Fetch các ticket ở **cột build-trigger** (`Approved`). Với **mỗi** ticket (tuần tự):

1. Tìm story liên kết qua trường `Ticket:`. Không tìm thấy story (vd ticket được người tạo tay, chưa qua đoạn 1) → báo trong log và bỏ qua (poll chỉ build story đã có ADR duyệt); KHÔNG tự tạo requirement/ADR ở đây.
2. Story chưa có `adr.md` → cảnh báo và bỏ qua (chưa qua thiết kế, không thể build an toàn).
3. **Idempotent check**: nếu story đã có `report.md` (đã build xong) → bỏ qua, không build lại.
4. Gọi skill **`deliver-auto {id}`**. Skill đó tự lo chuyển `in-progress` ở Phase 1 và `review` ở Phase 5. **Không hỏi gate** ở đây — gate đã được người vượt bằng thao tác kéo thẻ sang Approved.

**An toàn:** xử lý **tuần tự** từng ticket (deliver-auto cấm git worktree → mọi thay đổi trên một working tree chung; chạy song song nhiều build sẽ đè nhau).

## Bước 3 — Không đụng phần còn lại

KHÔNG fetch/không đổi ticket ở các cột `Validate` / `Review` / `Done` — đó là phần chờ người. Poll chỉ kích hoạt ở hai cột intake và Approved.

## Bước 4 — Tóm tắt lượt poll

Báo cho user (một khối ngắn): lượt này đã xử lý bao nhiêu ticket ở mỗi đoạn, story id nào được tạo/đẩy sang Validate, story nào được build sang Review, ticket nào bị bỏ qua và lý do. Nếu không có ticket nào ở intake/Approved → báo *"Không có ticket cần xử lý lượt này."*

## Ghi chú vận hành

- Chạy định kỳ: `/loop 10m /msdlc:tracking-poll` (interval, cần phiên đang mở) hoặc tạo scheduled cloud agent qua skill `schedule` (chạy nền kể cả tắt máy). Chọn theo nhu cầu; xem README.
- Mỗi lượt idempotent → chạy lại nhiều lần an toàn: trạng thái nằm ở cột board + sự tồn tại của `adr.md`/`report.md`.
