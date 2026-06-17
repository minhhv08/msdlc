---
name: commit
description: >-
  Tạo git commit tuân thủ quy ước msdlc: format (type): description, khai báo
  Co-Authored-By khi có sự hỗ trợ của AI. LUÔN dùng skill này khi user yêu cầu
  commit trong project dùng plugin msdlc, hoặc khi agent cần hướng dẫn cách
  commit sau khi hoàn thành công việc.
---

# /commit — Quy ước commit của msdlc

## Định dạng

```
(type): <mô tả thay đổi, ngắn gọn>

<body tuỳ chọn: giải thích vì sao, không quá 3-4 dòng>

Co-Authored-By: Claude Code
```

**Type hợp lệ:** `feat`, `fix`, `refactor`, `perf`, `docs`, `test`, `chore`, `build`, `ci`, `revert`

## Quy tắc

- Subject line: `(type): mô tả`, động từ hiện tại, không chấm cuối câu.
- Body (nếu cần): chỉ viết khi subject chưa đủ rõ — giải thích *vì sao*, không *làm thế nào*. Cách subject bằng một dòng trống.
- **Không liệt kê file đã sửa** — git diff đã thể hiện.
- Tiếng Việt hoặc tiếng Anh đều được, nhất quán trong một repo.

## Khai báo AI bắt buộc

Mọi commit được tạo hoặc hỗ trợ bởi công cụ AI **phải** có trailer ở footer:

```
Co-Authored-By: Claude Code
```

Hoặc `Co-Authored-By: Cursor` nếu dùng Cursor. Trailer cách body bằng một dòng trống.

Đây là bằng chứng bắt buộc để phân biệt code do người và do AI tạo ra, phục vụ đánh giá minh bạch mức độ đóng góp của AI.

## Cách commit (heredoc)

```bash
git commit -m "$(cat <<'EOF'
(feat): thêm endpoint health check cho service auth

Hỗ trợ k8s liveness probe, trả về 200 khi DB kết nối ok.

Co-Authored-By: Claude Code
EOF
)"
```

Commit một dòng đơn giản:

```bash
git commit -m "(fix): tránh null pointer khi user chưa có profile

Co-Authored-By: Claude Code"
```

## Ví dụ tốt / xấu

**Tốt:**
```
(fix): xử lý timeout khi gọi payment gateway > 5s

Retry tối đa 2 lần với exponential backoff trước khi fail.

Co-Authored-By: Claude Code
```

**Xấu** — thiếu trailer, type không đúng format, mô tả mơ hồ:
```
update payment code
```

**Xấu** — liệt kê file, dài dòng:
```
(feat): sửa file payment.go, thêm hàm retry, cập nhật config.yaml...
```

## Checklist

- [ ] Subject có format `(type): mô tả`, type nằm trong danh sách hợp lệ
- [ ] Body (nếu có) giải thích *vì sao*, cách subject một dòng trống
- [ ] Có trailer `Co-Authored-By` nếu AI đã tạo/hỗ trợ commit này
- [ ] Không liệt kê file trong subject
