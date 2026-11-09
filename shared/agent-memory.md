# Agent Memory — quy ước chung (bản gọn)

Mỗi agent có thư mục memory riêng `.claude/agent-memory-local/<tên-agent>/` (tương đối từ gốc workspace; Write tự tạo thư mục). Claude Code đã tự nạp `MEMORY.md` của agent khi khai báo `memory: local` — file này chỉ chốt phần quy ước riêng của msdlc.

**Mặc định: không đọc thêm, không ghi.** Chỉ ghi khi học được điều *không hiển nhiên* sẽ tiết kiệm công cho lần chạy sau.

## Nên lưu (4 loại, trường `type`)
- `feedback` — user sửa hoặc xác nhận một cách làm. Kèm **Why:** và **How to apply:**.
- `project` — bối cảnh không suy ra được từ code/git (deadline, lý do nghiệp vụ, freeze). Đổi ngày tương đối → tuyệt đối.
- `reference` — con trỏ tới hệ thống ngoài (board, dashboard, kênh).
- `user` — vai trò/sở thích làm việc của user.

Riêng từng agent có thể lưu **gotcha tái diễn** (vd key evict cache hay quên, quirk lệnh test, pattern noise log) — miễn là không suy ra nhanh từ code.

## KHÔNG lưu
Convention/kiến trúc/đường dẫn (thuộc `.claude/rules/` hoặc suy từ code), git history, cách fix bug, nội dung đã có trong CLAUDE.md/profile, trạng thái task đang dở.

## Cách ghi (2 bước)
1. Một file / một memory, frontmatter:
   ```markdown
   ---
   name: <kebab-slug>
   description: <một dòng, cụ thể>
   metadata:
     type: feedback | project | reference | user
   ---
   <nội dung>
   ```
2. Thêm một dòng `- [Title](file.md) — hook` (< 150 ký tự) vào `MEMORY.md`. Không ghi nội dung vào `MEMORY.md`.

**Giới hạn: `MEMORY.md` của mỗi agent tối đa ~30 dòng** — file này được nạp vào MỌI lần agent được gọi, nên mỗi dòng là chi phí lặp lại. Sắp vượt → gộp memory trùng/gần giống, xoá cái lỗi thời hoặc ít giá trị, trước khi thêm mới. Mỗi file memory cũng giữ ngắn (vài dòng).

Cập nhật thay vì tạo trùng; xóa memory sai/lỗi thời.

## Khi dùng memory
Memory là ảnh chụp quá khứ: trước khi hành động theo một memory nêu file/function/flag, kiểm tra nó còn tồn tại. Mâu thuẫn với hiện tại → tin hiện tại và sửa/xóa memory.
