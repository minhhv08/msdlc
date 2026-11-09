# spec — nhánh STORY (chỉ đọc khi Bước 0 phân loại là STORY)

## Điểm cần chốt (checklist nội bộ — KHÔNG in ra cho người dùng)

Dùng để xác định câu nào còn thiếu; điểm nào đã rõ từ mô tả/codebase thì bỏ qua:

- **Luồng chức năng:** vai trò nào làm thao tác gì → hệ thống phản hồi gì (3–7 luồng ở vòng đầu).
- **Dữ liệu:** input/field + validate; output/hiển thị/API trả về.
- **Quy tắc nghiệp vụ & phân quyền:** điều kiện, công thức, trạng thái chuyển đổi; ai được làm gì.
- **Trường hợp biên & lỗi:** rỗng/trùng/vượt giới hạn, lỗi tích hợp → xử lý thế nào.
- **Tích hợp & ràng buộc kỹ thuật:** hệ thống/module/API đang có phải đụng tới; bảo mật/dữ liệu nhạy cảm/hiệu năng — chỉ khi liên quan.
- **Ngoài phạm vi:** cái gì KHÔNG làm ở bản này (đưa ứng viên dễ bị scope creep thành option `multiSelect`).
- **Nghiệm thu:** 3–7 tiêu chí kiểm được — tự đề xuất từ các luồng, người dùng duyệt ở câu xác nhận cuối.

## Output: .claude/stories/{id}/requirement.md

Sau khi người dùng xác nhận bản tóm tắt, ghi spec ra file **`.claude/stories/{id}/requirement.md`** (tính từ thư mục gốc dự án), trong đó `{id}` là **số thứ tự kế tiếp, padding 3 chữ số** (`001`, `002`, …):

- Tìm các thư mục con đang có trong `.claude/stories/`, lấy số lớn nhất rồi +1. Nếu `.claude/stories/` chưa tồn tại hoặc rỗng → dùng `001`.
- Mỗi yêu cầu (mỗi lần chạy skill) là **một thư mục `.claude/stories/{id}/` riêng**, để các bước sau (architecture, vỡ task) ghi thêm file vào cùng thư mục đó.
- Tạo thư mục nếu chưa có. KHÔNG ghi đè thư mục/id đã tồn tại — luôn cấp id mới.

Nội dung file theo ĐÚNG template sau:

Template: `templates/requirement.md` trong thư mục skill này — Read ngay trước khi ghi file (nhánh STORY).

Quy tắc khi điền:
- Mỗi mục phải dựa trên câu trả lời thực của người dùng. Mục nào chưa rõ → để vào "Open questions", KHÔNG bịa.
- Giữ Scope ngắn gọn ở vòng đầu — thà ít luồng rõ ràng còn hơn nhiều luồng mơ hồ.
- Dùng ngôn ngữ cụ thể, kiểm được; thay "nhanh" bằng con số, thay "quản lý" bằng thao tác cụ thể.
- Mục không có nội dung thực (vd Constraints bảo mật) → ghi "—" hoặc bỏ dòng, không độn chữ.

## Sau khi xong

Báo cho người dùng biết file `.claude/stories/{id}/requirement.md` đã sẵn sàng (nêu rõ `{id}` đã cấp) và đây là input cho bước tiếp theo (thiết kế kiến trúc → vỡ task). Bước tiếp là **`/deliver {id}`** (architect → GATE duyệt ADR → build).

---
