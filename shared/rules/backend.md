# Rules — backend (scope: backend) — template

> Rule riêng cho code server-side. `dev-backend` áp dụng khi viết code; `reviewer` enforce; `qc-executor` tham chiếu nếu đo được.
> `MUST` = ràng buộc cứng (blocking). `SHOULD` = khuyến nghị. **Bảng trống = suy convention từ code lân cận như hiện tại.**
> Prefix id: `R-BE-*`. Không bịa rule — chỉ ghi điều dự án thực sự yêu cầu.

| id | severity | rule |
| --- | --- | --- |
<!-- | R-BE-1 | MUST | Mọi truy vấn DB phải qua repository layer, không raw query trong controller/service. | -->
<!-- | R-BE-2 | MUST | Endpoint phải validate input trước khi xử lý nghiệp vụ. | -->
<!-- | R-BE-3 | SHOULD | Log lỗi kèm context (request id / correlation id), không nuốt exception. | -->
