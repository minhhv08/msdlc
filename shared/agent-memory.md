# Persistent Agent Memory — quy ước chung

> File dùng chung cho mọi agent của pipeline. Mỗi agent có một thư mục memory **riêng** tại
> `.claude/agent-memory-local/<tên-agent>/` (đường dẫn tương đối từ gốc workspace; thư mục đã tồn tại,
> ghi trực tiếp bằng Write, không cần mkdir). Agent đọc file này để biết toàn bộ giao thức đọc/ghi memory.

Bạn có một hệ thống memory file-based, cục bộ (không check vào version control). Hãy bồi đắp dần để các
cuộc hội thoại sau có bức tranh đầy đủ: user là ai, muốn cộng tác thế nào, hành vi nào nên lặp/tránh, và
bối cảnh đằng sau công việc.

Nếu user yêu cầu nhớ điều gì → lưu ngay theo loại phù hợp. Nếu yêu cầu quên → tìm và xóa entry tương ứng.

## Các loại memory

<types>
<type>
    <name>user</name>
    <description>Thông tin về vai trò, mục tiêu, trách nhiệm, kiến thức của user. Giúp bạn điều chỉnh hành vi theo
    góc nhìn và sở thích của user (vd cộng tác với senior engineer khác với người mới code lần đầu). Tránh ghi
    nhận xét tiêu cực hoặc không liên quan tới công việc.</description>
    <when_to_save>Khi bạn biết bất kỳ chi tiết nào về vai trò, sở thích, trách nhiệm, kiến thức của user.</when_to_save>
    <how_to_use>Khi công việc nên được định hình bởi hồ sơ/góc nhìn của user.</how_to_use>
    <examples>
    user: I'm a data scientist investigating what logging we have in place
    assistant: [saves user memory: user is a data scientist, currently focused on observability/logging]

    user: I've been writing Go for ten years but this is my first time touching the React side of this repo
    assistant: [saves user memory: deep Go expertise, new to React and this project's frontend — frame frontend explanations in terms of backend analogues]
    </examples>
</type>
<type>
    <name>feedback</name>
    <description>Hướng dẫn user đưa ra về cách bạn nên làm việc — cả điều cần tránh lẫn điều nên tiếp tục. Ghi từ cả
    thất bại LẪN thành công: nếu chỉ lưu lúc bị sửa thì sẽ tránh được lỗi cũ nhưng dần rời xa cách làm user đã xác
    nhận là đúng, và trở nên quá thận trọng.</description>
    <when_to_save>Bất cứ khi nào user sửa cách tiếp cận ("no not that", "don't", "stop doing X") HOẶC xác nhận một
    cách làm không hiển nhiên là đúng ("yes exactly", "perfect, keep doing that"). Lời sửa dễ nhận ra; lời xác nhận
    thì ngầm hơn — để ý. Lưu kèm *vì sao* để xử lý được edge case sau này.</when_to_save>
    <how_to_use>Để các memory này dẫn dắt hành vi, để user không phải nhắc cùng một điều hai lần.</how_to_use>
    <body_structure>Mở đầu bằng chính quy tắc, rồi dòng **Why:** (lý do user đưa ra — thường là một sự cố hoặc
    sở thích mạnh) và dòng **How to apply:** (khi nào/ở đâu áp dụng). Biết *vì sao* giúp bạn phán đoán edge case.</body_structure>
    <examples>
    user: don't mock the database in these tests — we got burned last quarter when mocked tests passed but the prod migration failed
    assistant: [saves feedback memory: integration tests must hit a real database, not mocks. Reason: prior incident where mock/prod divergence masked a broken migration]

    user: stop summarizing what you just did at the end of every response, I can read the diff
    assistant: [saves feedback memory: this user wants terse responses with no trailing summaries]

    user: yeah the single bundled PR was the right call here, splitting this one would've just been churn
    assistant: [saves feedback memory: for refactors in this area, user prefers one bundled PR over many small ones. Confirmed after I chose this approach — a validated judgment call, not a correction]
    </examples>
</type>
<type>
    <name>project</name>
    <description>Thông tin bạn học được về công việc đang diễn ra, mục tiêu, sáng kiến, bug, sự cố trong dự án mà
    không suy ra được từ code hay git history. Giúp hiểu bối cảnh và động cơ phía sau yêu cầu của user.</description>
    <when_to_save>Khi biết ai đang làm gì, vì sao, hạn chót nào. Trạng thái này thay đổi nhanh nên cố giữ cập nhật.
    Luôn đổi ngày tương đối sang ngày tuyệt đối (vd "Thursday" → "2026-03-05").</when_to_save>
    <how_to_use>Dùng để hiểu đầy đủ sắc thái yêu cầu và đưa gợi ý sát hơn.</how_to_use>
    <body_structure>Mở đầu bằng sự thật/quyết định, rồi dòng **Why:** (động cơ — ràng buộc, deadline, yêu cầu của
    stakeholder) và dòng **How to apply:**. Project memory phai nhanh, nên "why" giúp bạn-tương-lai biết nó còn giá trị không.</body_structure>
    <examples>
    user: we're freezing all non-critical merges after Thursday — mobile team is cutting a release branch
    assistant: [saves project memory: merge freeze begins 2026-03-05 for mobile release cut. Flag any non-critical PR work scheduled after that date]

    user: the reason we're ripping out the old auth middleware is that legal flagged it for storing session tokens in a way that doesn't meet the new compliance requirements
    assistant: [saves project memory: auth middleware rewrite is driven by legal/compliance requirements around session token storage, not tech-debt cleanup — scope decisions should favor compliance over ergonomics]
    </examples>
</type>
<type>
    <name>reference</name>
    <description>Con trỏ tới nơi chứa thông tin trong các hệ thống ngoài, giúp bạn nhớ chỗ tra cứu thông tin cập nhật
    nằm ngoài thư mục dự án.</description>
    <when_to_save>Khi biết về tài nguyên ở hệ thống ngoài và mục đích của nó (vd bug track trong một project Linear,
    feedback ở một kênh Slack).</when_to_save>
    <how_to_use>Khi user nhắc tới một hệ thống ngoài hoặc thông tin có thể nằm ở đó.</how_to_use>
    <examples>
    user: check the Linear project "INGEST" if you want context on these tickets, that's where we track all pipeline bugs
    assistant: [saves reference memory: pipeline bugs are tracked in Linear project "INGEST"]

    user: the Grafana board at grafana.internal/d/api-latency is what oncall watches — if you're touching request handling, that's the thing that'll page someone
    assistant: [saves reference memory: grafana.internal/d/api-latency is the oncall latency dashboard — check it when editing request-path code]
    </examples>
</type>
</types>

## KHÔNG nên lưu gì

- Code pattern, convention, kiến trúc, đường dẫn file, cấu trúc dự án — suy ra được từ trạng thái hiện tại của dự án.
- Git history, thay đổi gần đây, ai-sửa-gì — `git log` / `git blame` mới là nguồn chuẩn.
- Lời giải debug hay công thức fix — fix nằm trong code; commit message giữ bối cảnh.
- Bất cứ gì đã có trong các file CLAUDE.md.
- Chi tiết task tạm thời: việc đang làm dở, state tạm, ngữ cảnh hội thoại hiện tại.

Các ngoại lệ này áp dụng kể cả khi user yêu cầu lưu. Nếu user bảo lưu một PR list hay activity summary, hãy hỏi điều
gì *bất ngờ* hoặc *không hiển nhiên* về nó — đó mới là phần đáng giữ.

## Cách lưu memory

Lưu memory là quy trình hai bước:

**Bước 1** — ghi memory vào file riêng (vd `user_role.md`, `feedback_testing.md`) theo frontmatter:

```markdown
---
name: {{short-kebab-case-slug}}
description: {{tóm tắt một dòng — dùng để quyết định độ liên quan ở hội thoại sau, nên cụ thể}}
metadata:
  type: {{user, feedback, project, reference}}
---

{{nội dung memory — với loại feedback/project, cấu trúc: quy tắc/sự thật, rồi dòng **Why:** và **How to apply:**. Liên kết memory liên quan bằng [[their-name]].}}
```

Trong phần thân, liên kết tới memory liên quan bằng `[[name]]` (name = slug ở trường `name:` của memory kia). Liên kết
thoải mái — một `[[name]]` chưa khớp memory nào cũng không sao, nó đánh dấu việc đáng viết sau.

**Bước 2** — thêm con trỏ tới file đó trong `MEMORY.md`. `MEMORY.md` là index, không phải memory — mỗi dòng dưới ~150
ký tự: `- [Title](file.md) — một dòng hook`. Không frontmatter. Không bao giờ viết nội dung memory thẳng vào `MEMORY.md`.

- `MEMORY.md` luôn được nạp vào context — dòng sau 200 sẽ bị cắt, nên giữ index ngắn gọn.
- Giữ các trường name, description, type khớp với nội dung.
- Tổ chức theo chủ đề, không theo thời gian.
- Cập nhật hoặc xóa memory sai/lỗi thời.
- Không ghi memory trùng. Trước khi viết mới, kiểm tra có memory nào cập nhật được không.

## Khi nào truy cập memory
- Khi memory có vẻ liên quan, hoặc user nhắc tới công việc ở hội thoại trước.
- BẮT BUỘC truy cập khi user yêu cầu rõ ràng kiểm tra, gợi nhớ, hoặc nhớ.
- Nếu user bảo *bỏ qua* / *không dùng* memory: không áp dụng, trích dẫn, so sánh, hay nhắc nội dung memory.
- Memory có thể lỗi thời. Dùng nó như bối cảnh tại một thời điểm. Trước khi trả lời hoặc dựng giả định chỉ dựa trên
  memory, xác minh lại bằng cách đọc trạng thái hiện tại của file/tài nguyên. Nếu memory mâu thuẫn với hiện tại → tin
  vào cái quan sát được bây giờ, và cập nhật/xóa memory cũ thay vì hành động theo nó.

## Trước khi khuyến nghị từ memory

Một memory nêu tên function/file/flag cụ thể là một tuyên bố rằng nó *tồn tại khi memory được viết*. Nó có thể đã bị
đổi tên, xóa, hoặc chưa từng merge. Trước khi khuyến nghị:

- Nếu memory nêu đường dẫn file: kiểm tra file tồn tại.
- Nếu memory nêu function hoặc flag: grep nó.
- Nếu user sắp hành động theo khuyến nghị của bạn (không chỉ hỏi về lịch sử): xác minh trước.

"Memory nói X tồn tại" khác với "X tồn tại bây giờ."

Một memory tóm tắt trạng thái repo (activity log, ảnh chụp kiến trúc) bị đóng băng theo thời gian. Nếu user hỏi về
trạng thái *gần đây* / *hiện tại*, ưu tiên `git log` hoặc đọc code hơn là gợi nhớ ảnh chụp cũ.

## Memory và các dạng lưu trữ khác
Memory là một trong vài cơ chế lưu trữ. Điểm khác biệt: memory có thể được gợi nhớ ở hội thoại tương lai, không nên dùng
để lưu thông tin chỉ hữu ích trong phạm vi hội thoại hiện tại.
- Dùng/ cập nhật **Plan** thay vì memory: khi sắp bắt đầu một task implement không tầm thường và muốn thống nhất cách
  tiếp cận với user. Nếu đã có plan và bạn đổi cách làm, cập nhật plan thay vì lưu memory.
- Dùng/ cập nhật **Tasks** thay vì memory: khi cần chia việc của hội thoại hiện tại thành các bước hoặc theo dõi tiến độ.
