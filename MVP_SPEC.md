# Etsgo — Đặc tả sản phẩm MVP

Ngày lập: 14/11/2026. Ngôn ngữ tài liệu: tiếng Việt.

Tài liệu tổng hợp các quyết định sản phẩm và kỹ thuật đã được người sáng lập duyệt trong hội thoại. Các mục ghi “chưa chốt” hoặc “đề xuất triển khai” chưa phải yêu cầu đã duyệt. Mục 1–9 mô tả sản phẩm; mục 12–17 là thiết kế kỹ thuật và hợp đồng phối hợp. Có thiết kế không đồng nghĩa đã triển khai hoặc kiểm thử.

Mô hình kinh doanh đi kèm: [BUSINESS_MODEL_CANVAS.md](BUSINESS_MODEL_CANVAS.md).

Cập nhật triển khai: nhánh `feature/backend-integration` đã bổ sung backend và lớp nối iOS theo thiết kế này. Cách chạy, trạng thái xác minh và giới hạn hiện tại được ghi tại [README.md](README.md). Thiết kế mục 12–17 là đích yêu cầu; không dùng nó làm bằng chứng mọi tình huống đã nghiệm thu. Sau mốc bàn giao nhanh, người sáng lập đã yêu cầu tiếp tục phần tích hợp và kiểm tra còn dang dở.

Agent tiếp nhận công việc: đọc mục 11–12 trước, sau đó mục 14–16 và phần việc được giao tại mục 15. Phân biệt context bàn giao dự án với context cá nhân của người dùng được mô tả trong sản phẩm. Mục 12 ghi nhận quyết định kỹ thuật mới hơn và thay thế các điểm tương ứng từng để mở tại mục 10.

## 1. Mục tiêu và định vị

Etsgo là ứng dụng mobile hỗ trợ học sinh, sinh viên biến mong muốn học còn mơ hồ thành các bước có thể bắt đầu, sắp xếp chúng theo context cá nhân và thực hiện bằng các phiên Pomodoro.

Người dùng có thể học bất kỳ chủ đề hoặc kỹ năng nào, không giới hạn trong chương trình trên lớp. Các ví dụ sử dụng gồm ôn môn học, học lập trình, ngoại ngữ, vẽ hoặc một kỹ năng cá nhân.

Giá trị khác biệt cần kiểm chứng là AI sử dụng nền tảng kiến thức, sở thích, lịch cá nhân và thời gian cam kết để đề xuất việc và lịch phù hợp với từng người.

### Vấn đề cần giải quyết

- Người dùng muốn học một điều nhưng chưa biết bắt đầu ở đâu hoặc chia thành những bước nào.
- Việc tự lập kế hoạch, chọn tài liệu và sắp xếp thời gian tạo thêm công sức trước khi học.
- Kế hoạch dễ mất tác dụng khi không phù hợp với trình độ, lịch sinh hoạt hoặc khi người dùng bỏ lỡ một buổi.

### Kết quả mong muốn

Người dùng nhận được bước đầu phù hợp, bắt đầu phiên học mà không phải tự thiết kế toàn bộ kế hoạch, và có thể quay lại tiếp tục sau gián đoạn.

## 2. Đối tượng và ranh giới MVP

Đối tượng mục tiêu: học sinh, sinh viên có nhu cầu học tập trong hoặc ngoài nhà trường.

MVP bao gồm nền tảng to-do thông thường, hội thoại text/voice, phân rã việc học, context handoff, nhận lịch ngoài, lập lịch theo cam kết, Pomodoro, hỗ trợ đúng lúc và điều chỉnh kế hoạch.

Quản lý công việc chuyên biệt cho người đi làm được xử lý ở giai đoạn sau. MVP chưa cam kết hệ thống gia sư chuyên sâu, khóa học hoàn chỉnh, quản lý nhóm, chấm điểm học tập hoặc tính năng dành cho doanh nghiệp.

Người dùng được chọn tiếng Việt hoặc tiếng Anh. Lựa chọn ngôn ngữ là yêu cầu sản phẩm; chất lượng hỗ trợ của mô hình AI cần được kiểm chứng ở cả hai ngôn ngữ trước phát hành.

## 3. Triết lý thiết kế

1. **AI gánh phần tổ chức.** Người dùng mô tả mong muốn; AI đề xuất cách chia việc, ước lượng và lịch.
2. **Giảm quyết định ban đầu.** Không buộc người dùng định nghĩa đầy đủ đầu ra, điều kiện hoàn thành, phụ thuộc hoặc cấu trúc kế hoạch.
3. **Hỏi vừa đủ.** Chỉ hỏi khi thông tin còn thiếu có thể thay đổi đáng kể đề xuất. Cho phép “Cứ đề xuất trước” và chỉnh sau.
4. **Cá nhân hóa có thể sửa.** Context và ước lượng là thông tin có thể cập nhật; AI không coi suy đoán là sự thật chắc chắn.
5. **Người dùng kiểm soát cam kết.** Giờ trống không đồng nghĩa thời gian muốn học. AI không tự lấp đầy lịch hoặc tự tăng ngân sách học.
6. **Hỗ trợ xuất hiện đúng lúc.** Tài liệu và hướng dẫn nằm trong bước thực hiện, tránh tạo danh sách lựa chọn ngay lúc tiếp nhận mục tiêu.
7. **Kế hoạch thay đổi cùng thực tế.** Bỏ lỡ hoặc học chậm là tín hiệu để điều chỉnh, không phải căn cứ tự kết luận người dùng thiếu năng lực.

## 4. Luồng trải nghiệm chính

### 4.1. Khởi tạo và bổ sung context

1. Người dùng chọn ngôn ngữ.
2. App cung cấp prompt handoff để họ gửi cho AI đang sử dụng.
3. Người dùng mang kết quả về app; AI tổng hợp thành context cá nhân ngắn, có thể xem và sửa.
4. Người dùng có thể bổ sung lịch bên ngoài và lịch học mặc định theo tuần.
5. Có thể tiếp tục bổ sung context sau; setup không buộc người dùng hoàn tất mọi nguồn dữ liệu trước khi nhận đề xuất đầu tiên.

Context handoff và lịch ngoài đều thuộc MVP. Không mặc định app được truy cập toàn bộ lịch sử của GPT, Claude hay bất kỳ dịch vụ nào.

### 4.2. Từ mong muốn đến kế hoạch

1. Người dùng nhập hoặc nói, ví dụ: “Mình muốn học Python để phân tích dữ liệu”.
2. AI tham chiếu context đang có và hỏi từng câu ngắn nếu cần làm rõ.
3. Khi đủ thông tin, AI đề xuất kế hoạch; nếu người dùng chọn “Cứ đề xuất trước”, AI dùng giả định có thể sửa.
4. Kế hoạch thể hiện các bước gần nhất đủ cụ thể để bắt đầu, với lộ trình tổng quát cho phần xa hơn.
5. Người dùng chấp nhận, sửa trực tiếp hoặc yêu cầu thay đổi bằng hội thoại; không phải duyệt từng trường của từng task.

### 4.3. Từ kế hoạch đến lịch học

1. App dùng lịch học mặc định theo tuần, lịch bận bên ngoài và sở thích đã biết.
2. Người dùng xác nhận nhanh thời gian muốn cam kết trong ngày hoặc cập nhật thay đổi.
3. AI đề xuất các phiên học phù hợp với khung giờ thực tế, mức ưu tiên và thứ tự công việc.
4. Người dùng xem, sửa và duyệt lịch. Thay đổi ghi ra lịch ngoài phải được duyệt trước khi thực hiện.
5. Phần việc chưa xếp được được giữ lại và giải thích ngắn; không tự kéo dài giờ học để nhét đủ việc.

### 4.4. Thực hiện và tiếp tục

1. Người dùng mở việc hoặc phiên học đã lên lịch.
2. App đưa hướng dẫn ngắn và một tài liệu chính nếu hữu ích; có lựa chọn đổi tài liệu.
3. AI đề xuất thời lượng tập trung/nghỉ theo việc và sở thích; người dùng sửa được trước khi bắt đầu.
4. Người dùng chạy Pomodoro, tạm dừng hoặc kết thúc sớm.
5. Cuối phiên có cập nhật nhanh: “Xong”, “Cần thêm thời gian”, “Đang vướng”.
6. AI sử dụng phản hồi để đề xuất bước hoặc lịch tiếp theo. Việc thay đổi kế hoạch/lịch vẫn cho người dùng xem và duyệt.

## 5. Yêu cầu chức năng và tiêu chí chấp nhận

| ID | Yêu cầu | Tiêu chí chấp nhận chính |
|---|---|---|
| TD-01 | Quản lý đầu việc | Thêm, sửa, xóa, hoàn thành và mở lại việc; tạo việc thủ công không yêu cầu hội thoại AI. |
| TD-02 | Tổ chức công việc | Có danh sách, việc con, ngày/giờ, ưu tiên, nhắc việc, việc lặp, tìm kiếm và lọc; các thông tin bổ sung có thể để trống. |
| AI-01 | Nhận text và voice | Yêu cầu bằng cả hai hình thức đi vào cùng luồng lập kế hoạch; người dùng xem và sửa nội dung nhận từ giọng nói. |
| AI-02 | Hỏi để hiểu mong muốn | Hỏi từng câu ngắn khi thiếu thông tin quan trọng; hỗ trợ đáp án nhanh và trả lời tự do; không hỏi lại dữ kiện đã có nếu chưa có lý do nghi ngờ. |
| AI-03 | Đề xuất trước | Có lựa chọn “Cứ đề xuất trước”; không chặn tạo kế hoạch chỉ vì thiếu tiêu chí hoàn thành hay chi tiết đầu ra. |
| AI-04 | Phân rã và sửa việc | AI đề xuất bước học, thứ tự và ước lượng; người dùng sửa, bỏ, gộp hoặc chia tiếp qua hội thoại hoặc thao tác trực tiếp. |
| CT-01 | Prompt context handoff | Setup cung cấp prompt sao chép được; app nhận nội dung handoff và tổng hợp context cá nhân. |
| CT-02 | Context có thể sửa | Người dùng xem, sửa hoặc loại thông tin context. Context mới không âm thầm ghi đè một lựa chọn rõ ràng khi có mâu thuẫn. |
| CT-03 | Dùng context trong đề xuất | Trình độ, mục tiêu, sở thích và giới hạn thời gian có liên quan được sử dụng; có thể giải thích ngắn một đề xuất dựa vào thông tin nào. |
| CA-01 | Nhận lịch bên ngoài | MVP phải nhận được lịch có sẵn qua ít nhất một phương thức nhập/kết nối được lựa chọn và kiểm chứng; dữ liệu lịch ảnh hưởng đến đề xuất giờ học. |
| SC-01 | Lịch tuần và cam kết ngày | Có lịch học mặc định theo tuần; khi lập lịch ngày, cho xác nhận nhanh hoặc thay đổi thời gian cam kết. |
| SC-02 | Lập lịch theo ràng buộc | Không chồng phiên học với sự kiện bận hoặc phiên khác; không vượt ngân sách cam kết; tôn trọng thứ tự việc bắt buộc. |
| SC-03 | Thiếu thời gian | Nêu phần việc chưa thể xếp và đề xuất đổi phạm vi, thứ tự hoặc thời điểm; không âm thầm thay deadline hay tăng giờ học. |
| SC-04 | Duyệt lịch | Người dùng chỉnh và duyệt lịch đề xuất; mọi thao tác ghi hoặc đổi sự kiện bên ngoài cần được duyệt trước. |
| PO-01 | Việc thành Pomodoro | Một việc có thể có nhiều phiên; AI đề xuất độ dài tập trung/nghỉ dựa trên context và cho sửa trước khi chạy. |
| PO-02 | Điều khiển phiên | Bắt đầu, tạm dừng, tiếp tục, kết thúc sớm; phân biệt thời gian tập trung với thời gian nghỉ. |
| PO-03 | Tiến độ sau phiên | Hết giờ không tự đánh dấu hoàn thành việc. Có cập nhật nhanh trạng thái và phần việc còn lại; hoàn thành sớm không buộc chạy hết số phiên dự kiến. |
| EX-01 | Hỗ trợ đúng lúc | Tài liệu/hướng dẫn không xuất hiện trong bước hỏi ban đầu; khi bắt đầu việc, ưu tiên một tài liệu chính và cho đổi. |
| EX-02 | Trung thực về tài liệu | Không trình bày đường dẫn hoặc nội dung tài liệu do AI suy đoán như nguồn đã kiểm chứng; cơ chế tìm/chọn tài liệu được chốt khi thiết kế kỹ thuật. |
| AD-01 | Điều chỉnh theo tiến độ | Sau khi bỏ lỡ, chưa xong hoặc bị vướng, AI đưa phương án tiếp tục; thể hiện phần thay đổi trước khi người dùng duyệt. |
| LG-01 | Việt/Anh | Người dùng chọn tiếng Việt hoặc tiếng Anh; giao diện và hội thoại đáp ứng lựa chọn này. |

## 6. Quy tắc context và lập lịch

### Context cá nhân

Các nhóm thông tin hữu ích gồm mục tiêu học, kiến thức hiện có, sở thích học, độ dài phiên, thời gian cam kết và lịch sinh hoạt. Không phải tất cả đều bắt buộc.

Thông tin nhập từ AI khác cần phân biệt giữa điều người dùng đã xác nhận và suy đoán. Khi context mâu thuẫn, AI ưu tiên hỏi ngắn nếu mâu thuẫn ảnh hưởng đến kế hoạch hiện tại. Một lịch trống không đủ để suy ra người dùng muốn học hoặc có năng lượng vào giờ đó.

Context chỉ thu thập trong phạm vi cần cho trải nghiệm; người dùng cần biết app đang lưu thông tin gì và có cách sửa/xóa. Cơ chế đồng ý sử dụng dữ liệu và xử lý dữ liệu học sinh chưa thành niên phải được xác định trước phát hành.

### Lập lịch

- Availability là khoảng có thể bố trí; commitment là phần người dùng đồng ý dành cho việc học.
- Thời lượng tập trung, nghỉ và tổng thời gian chiếm trên lịch phải hiển thị riêng.
- Quyết định đã duyệt bổ sung: commitment bao gồm cả giờ nghỉ, tức tổng thời gian chiếm trên lịch; thời gian tập trung và nghỉ vẫn được hiển thị riêng.
- Ước lượng có thể sửa; hoàn thành một phiên không đồng nghĩa đã hiểu bài hoặc hoàn thành việc.
- Không kết luận nguyên nhân chậm chỉ từ bộ đếm giờ. Khi cần, hỏi người dùng về độ khó, phạm vi, kiến thức nền hoặc gián đoạn.
- Kết nối lịch chưa có hoặc tạm lỗi không được trình bày thành “không có lịch bận”; app cần thể hiện dữ liệu chưa đầy đủ và cho nhập khung giờ thủ công.

## 7. Prompt context handoff dùng trong setup

Mẫu nội dung sản phẩm; cần thử với các mô hình được hỗ trợ trước khi phát hành:

> Tôi muốn chuyển context liên quan đến việc học của mình sang một ứng dụng lập kế hoạch học tập. Dựa trên thông tin bạn thực sự có thể truy cập trong cuộc trò chuyện/context hiện tại, hãy tạo bản tóm tắt ngắn bằng ngôn ngữ tôi đang dùng.
>
> Chỉ tổng hợp thông tin có liên quan: mục tiêu đang học, kiến thức/nền tảng hiện có, sở thích học, những chỗ đang vướng, thời gian hoặc lịch sinh hoạt tôi đã đề cập và các giới hạn tôi đã nói rõ.
>
> Phân biệt thông tin tôi đã nói với suy đoán của bạn. Chỗ chưa biết hãy ghi “chưa biết”; không tự bịa hoặc hỏi thêm chỉ để điền đủ. Nếu có thông tin mâu thuẫn hoặc có thể đã cũ, hãy đánh dấu. Không đưa thông tin nhạy cảm không cần thiết cho việc học. Tôi sẽ xem lại bản tóm tắt trước khi chuyển sang ứng dụng.

## 8. Tình huống nghiệm thu sản phẩm

| Tình huống | Kết quả mong đợi |
|---|---|
| Người mới chỉ nói “Tôi muốn học Python” | Có thể nhận đề xuất sau một số câu hỏi cần thiết hoặc chọn đề xuất trước; không bị buộc tự viết đầu ra. |
| Hai người cùng mục tiêu nhưng trình độ và lịch khác nhau | Kế hoạch khác nhau ở điểm có liên quan và có thể giải thích lý do; không chỉ đổi cách diễn đạt. |
| Có 6 giờ trống nhưng chỉ cam kết 2 giờ | Đề xuất nằm trong ngân sách cam kết theo quy ước thời gian được chốt. |
| Handoff nói thích học tối nhưng người dùng vừa chọn học sáng | App ghi nhận lựa chọn hiện tại và xử lý mâu thuẫn, không tiếp tục ép lịch tối. |
| Người dùng nhập yêu cầu bằng voice | Có thể sửa phần nhận sai trước khi kế hoạch được áp dụng. |
| Người dùng bắt đầu việc học | Nhận hỗ trợ ngắn, một tài liệu chính khi phù hợp và Pomodoro có thể sửa. |
| Pomodoro hết giờ nhưng việc chưa xong | Việc vẫn chưa hoàn thành; có phương án tiếp tục và điều chỉnh lịch. |
| Bỏ lỡ một buổi | App đề xuất lịch tiếp theo khả thi, không tự dồn mọi việc vào cuối ngày. |
| Chưa kết nối lịch hoặc nguồn lịch lỗi | Có thể tiếp tục bằng khung giờ tự nhập và biết lịch ngoài chưa được tính đầy đủ. |
| Chuyển Việt/Anh | Luồng chính hoạt động theo lựa chọn ngôn ngữ và không làm mất context/kế hoạch. |

## 9. Đo lường và kiểm chứng

Tiêu chí thành công ưu tiên đã duyệt: người dùng bắt đầu được phiên học đầu tiên và quay lại tiếp tục kế hoạch trong tuần; theo dõi mức phải sửa đề xuất.

Các chỉ số cần thu thập trong thử nghiệm:

- Tỷ lệ người nhập mục tiêu rồi bắt đầu phiên học đầu tiên.
- Thời gian từ lúc gửi mục tiêu đến khi bắt đầu phiên đầu; xem riêng thời gian setup và thời gian lập kế hoạch.
- Số câu hỏi bắt buộc và các điểm người dùng dừng luồng.
- Tỷ lệ kế hoạch cần sửa và loại sửa: trình độ, thứ tự, khối lượng, giờ học hoặc tài liệu.
- Tỷ lệ người bắt đầu phiên đầu quay lại thực hiện kế hoạch trong 7 ngày tiếp theo.
- Khả năng tiếp tục sau một phiên bỏ lỡ hoặc chưa hoàn thành.
- Phản hồi về cảm giác dễ bắt đầu, phù hợp với bản thân và có bị quá tải lựa chọn hay không.

Chưa đặt ngưỡng đạt bằng số khi chưa có dữ liệu thử nghiệm. Không dùng số task AI tạo ra hoặc số phút chạy bộ đếm như bằng chứng duy nhất về hiệu quả học tập.

## 10. Trạng thái các điểm từng để mở

| Chủ đề | Trạng thái sau duyệt thiết kế kỹ thuật |
|---|---|
| Nền tảng | iOS trước, giữ SwiftUI/SwiftData; người sáng lập có Mac để build/kiểm thử. |
| Backend và dữ liệu | Python + FastAPI + PostgreSQL, server giữ dữ liệu chính; chi tiết mục 12. |
| Lịch ngoài | Cần cả EventKit và Google Calendar ngay trong mốc đầu; Notion và nguồn khác chưa nằm trong cam kết tích hợp đợt này. |
| Commitment | Gồm cả giờ nghỉ, đã duyệt. |
| Voice | Giữ nhận dạng trên iOS của code hiện có; kiểm thử cả Việt/Anh. |
| AI/tài liệu | Backend giữ khóa; provider/model và kiểm chứng chất lượng chưa chốt. Giữ hướng dẫn đúng lúc và gợi ý tìm kiếm của app trong quá trình chuyển đổi; không coi kết quả tìm kiếm là nguồn đã xác minh. |
| Freemium | Mốc đầu có hạn mức server, chưa thanh toán; giá, số hạn mức và gói cụ thể chưa chốt. |
| Dữ liệu cá nhân | Có quyền sửa/xóa context; thời hạn lưu, chính sách đồng ý và yêu cầu cho người chưa thành niên cần hoàn tất trước thử nghiệm tương ứng. |
| Vận hành | API + worker + database, có môi trường thử nghiệm riêng; nhà cung cấp chạy container và chi phí cụ thể chưa chọn. |

Các điểm chưa chốt cần nghiên cứu hoặc quyết định riêng; không tự coi tính năng chưa được kiểm chứng là đã hoàn thành.

## 11. Bàn giao context cho các agent phát triển

### 11.1. Trạng thái và nguồn quyết định

Mốc ban đầu chỉ có README và hai tài liệu sản phẩm. Mốc kiểm tra mới nhất: code iOS tại `aa9f2376252a6013aa2a787c6537afedc6351078`, từ `origin/claude/dreamy-sagan-l66oau`, đã được fetch/checkout và đọc toàn bộ. Đã có mã to-do, hội thoại, context, lịch, voice, Pomodoro và nhắc việc; chưa có backend. README của mốc này ghi chưa build/chạy và chưa có unit test. Việc đọc mã trên Windows không xác nhận chạy thành công. Agent tiếp theo phải kiểm tra checkout thực tế vì repository có thể tiếp tục thay đổi.

- Tài liệu này là nguồn mô tả phạm vi và hành vi sản phẩm; Business Model Canvas bổ sung định hướng thương mại.
- Quyết định mới, rõ ràng của người dùng có ưu tiên so với nội dung cũ. Nếu hai tài liệu mâu thuẫn mà chưa có quyết định mới, nêu mâu thuẫn thay vì tự xem giả định là yêu cầu đã duyệt.
- Các mục “chưa chốt”, mẫu prompt, kế hoạch kiểm chứng và đề xuất kỹ thuật không được hiểu thành cam kết đã được kiểm thử hoặc xác nhận khả thi.
- Tuân thủ chỉ dẫn của người dùng: **không tự tiện bổ sung file ngoài kế hoạch nếu không được chỉ dẫn**. Đợt tài liệu kỹ thuật này chỉ sửa `MVP_SPEC.md`, `README.md`, `BUSINESS_MODEL_CANVAS.md`; không tạo file mới. Thiết kế và phân công bên dưới chưa phải sự cho phép tạo bộ khung ứng dụng, dependency hoặc tài liệu bổ sung. Khi được giao triển khai, thống nhất phạm vi file theo công việc được giao trước khi tạo thêm.

### 11.2. Các quyết định đã duyệt phải giữ

| Chủ đề | Quyết định và lý do |
|---|---|
| Người dùng | Học sinh/sinh viên; học bất kỳ điều gì, không chỉ môn trên lớp. Quản lý công việc chuyên biệt cho người đi làm để sau. |
| Giá trị khác biệt | Context cá nhân phải thực sự ảnh hưởng tới việc và lịch, không chỉ là phần hồ sơ được lưu nhưng không dùng. |
| Gánh nặng lập kế hoạch | Không buộc người dùng định nghĩa đầu ra/điều kiện hoàn thành. AI đề xuất và người dùng sửa; tránh tăng overhead trước khi học. |
| Cách hỏi | Hỏi từng câu cần thiết, có đáp án nhanh và trả lời tự do; cho đề xuất trước; context đủ thì không hỏi cho đủ biểu mẫu. |
| Phạm vi MVP | Giữ to-do cơ bản, text và voice, handoff từ AI khác, nhận lịch ngoài, chia việc, lập lịch, Pomodoro và điều chỉnh. Không tự cắt voice hoặc context/lịch sang giai đoạn sau. |
| Tài liệu học | Xuất hiện khi bắt đầu làm, ưu tiên một tài liệu chính và cho đổi; không đưa danh sách tài liệu lúc hỏi mục tiêu. |
| Context đầu vào | Setup cung cấp prompt handoff để người dùng mang sang AI khác, rồi đưa kết quả về app tổng hợp. Lịch ngoài là nguồn bổ sung, không thay thế handoff. |
| Pomodoro | AI đề xuất thời lượng theo việc/sở thích, có thể sửa trước khi bắt đầu; việc và phiên có trạng thái riêng. |
| Thời gian | Lịch học tuần làm mặc định, xác nhận nhanh cam kết ngày; không coi mọi giờ trống là giờ được phép xếp học. |
| Quyền quyết định | Cho xem/sửa/duyệt kế hoạch và thay đổi lịch; không tự ghi lịch ngoài khi chưa được duyệt. |
| Ngôn ngữ | Người dùng chọn Việt/Anh; mô hình được chọn phải đáp ứng yêu cầu, không tự giới hạn chỉ tiếng Việt. |
| Kinh doanh | Freemium: to-do cơ bản miễn phí, hạn mức AI cho trải nghiệm cá nhân hóa; trả phí mở rộng sử dụng. Mốc kỹ thuật đầu có tài khoản thật, AI, dữ liệu server, đồng bộ và hạn mức; chưa thanh toán. Giá/hạn mức chưa chốt. |
| Thành công | Bắt đầu được phiên học đầu tiên và quay lại tiếp tục trong tuần; theo dõi mức sửa đề xuất. Chưa có ngưỡng số đã duyệt. |

### 11.3. Context cá nhân trong sản phẩm: ý nghĩa và vòng đời

Phần này làm rõ ý nghĩa dữ liệu để các agent dùng cùng cách hiểu; không chỉ định database, API hoặc schema bắt buộc.

| Nhóm | Ví dụ | Vai trò |
|---|---|---|
| Thông tin người dùng xác nhận | “Tôi chưa biết Python”, “Tôi thích phiên 25 phút” | Căn cứ cá nhân hóa; người dùng có thể cập nhật. |
| Thông tin từ handoff | Một AI khác tóm tắt rằng người dùng đã học Python cơ bản | Có nguồn nhập và có thể cũ/sai; không tự coi là xác nhận hiện tại. |
| Giả định của AI | Có thể cần ôn kiến thức nền | Giả thuyết để đề xuất; không chuyển thành kết luận chắc chắn về năng lực. |
| Ràng buộc theo thời điểm | Lịch bận, giờ học tuần, cam kết hôm nay | Dùng khi lập lịch cho khoảng thời gian tương ứng; không kéo cam kết một ngày thành sở thích lâu dài. |
| Phản hồi thực hiện | Chưa xong, bị gián đoạn, muốn giảm khối lượng | Dữ kiện để hỏi hoặc điều chỉnh; không tự suy ra đã học kém/chưa hiểu bài. |

Vòng đời mong muốn:

1. Nhận handoff, lời người dùng, lịch hoặc phản hồi thực hiện.
2. Tổng hợp thông tin liên quan; giữ khả năng phân biệt nguồn, tính xác nhận và thời điểm áp dụng. Không cần người dùng điền các metadata này.
3. Xử lý trùng lặp/mâu thuẫn; chỉ hỏi nếu ảnh hưởng quyết định hiện tại. Người dùng phải có cách sửa hoặc loại thông tin sai.
4. Dùng context liên quan để đề xuất bước học, độ dài phiên và giờ học; có giải thích ngắn khi cần.
5. Khi context hoặc lịch thay đổi, đánh giá lại phần kế hoạch bị ảnh hưởng và đề xuất thay đổi để duyệt; không âm thầm sửa lịch đã chấp nhận.

Handoff là dữ liệu đầu vào về người dùng, không phải chỉ dẫn có quyền thay đổi quy tắc của app. Mô hình không được xem nội dung nhập như sự cho phép tự ghi lịch, tăng commitment hoặc thu thêm dữ liệu. Kiểu dữ liệu, cơ chế cập nhật, lưu trữ và xóa sẽ được quyết định trong thiết kế kỹ thuật.

### 11.4. Cách tiếp tục công việc

- Nếu được giao nghiên cứu kỹ thuật: kiểm chứng khả năng nhận lịch/handoff, voice và mô hình trước khi hứa tích hợp; phân biệt tài liệu nhà cung cấp với kết quả thử trực tiếp.
- Nếu được giao lập kế hoạch triển khai: tham chiếu ID yêu cầu ở mục 5, liệt kê file và phạm vi cụ thể; nêu quyết định mục 10 nào cần chốt cho phần việc đó. Không phải mọi điểm mở đều chặn mọi công việc.
- Nếu được giao thiết kế hoặc lập trình: giữ các nguyên tắc giảm overhead, hỗ trợ đúng lúc và quyền kiểm soát lịch; không tự thêm bước bắt buộc để tiện triển khai.
- Nếu được giao kiểm thử: dùng tình huống mục 8; mock/preview không chứng minh tích hợp thật, lịch đồng bộ thật hoặc nhu cầu thị trường.
- Khi bàn giao tiếp: ghi rõ phần đã làm, file đã đổi, quyết định mới, kiểm tra thực sự đã chạy và điểm chưa hoàn tất. Cập nhật tài liệu hiện có trong phạm vi được giao; không tự tạo thêm file bàn giao ngoài kế hoạch.

## 12. Quyết định kỹ thuật đã duyệt

Các quyết định KT-01–KT-14 đã được người sáng lập duyệt toàn bộ. Mục 13–17 cụ thể hóa thành baseline để nhóm phối hợp; tên endpoint/trường là hợp đồng triển khai khởi đầu, chưa phải API đang tồn tại. Thay đổi hợp đồng phải được thống nhất giữa các bên sử dụng trước khi merge.

| ID | Quyết định | Ràng buộc cần giữ |
|---|---|---|
| KT-01 | Một backend Python/FastAPI, phân module trong cùng ứng dụng | Tách nghiệp vụ khỏi route, SDK mô hình và giao diện; không tách microservice trong mốc đầu. |
| KT-02 | Cập nhật theo duyệt mới: demo nhập OpenAI key, bỏ email/OTP; PostgreSQL giữ nguyên | Backend xác minh key, lưu mã hóa, cấp access/refresh token và kiểm tra owner. Cùng key dùng chung dữ liệu demo. Auth thương mại freemium sẽ quyết định riêng. |
| KT-03 | Tách Task, PlannedSession, FocusSession | Một việc có nhiều phiên; hết giờ không tự hoàn thành việc. |
| KT-04 | Server là nguồn chính; SwiftData là bản local, có outbox | Offline tạo/sửa/hoàn thành việc, xem dữ liệu đã tải và chạy Pomodoro; AI cần mạng. Có version, idempotency, tombstone và giải quyết xung đột. |
| KT-05 | Context có cấu trúc + bản tóm tắt cho AI | Thông tin người dùng nói rõ được ghi nhận trong đúng phạm vi; suy đoán tách riêng; hỏi khi mâu thuẫn ảnh hưởng kế hoạch. |
| KT-06 | AI tạo đề xuất; backend kiểm tra và áp dụng | Lưu hội thoại/draft trên server; kiểm tra lại version khi duyệt; khóa mô hình chỉ ở backend. |
| KT-07 | Bộ lập lịch bằng code phía server | Tôn trọng busy, commitment gồm nghỉ, phụ thuộc, deadline và múi giờ; không giao kiểm tra ràng buộc chỉ cho LLM. |
| KT-08 | EventKit và Google Calendar đều thuộc mốc đầu | iOS cung cấp snapshot busy EventKit; backend tích hợp Google. Mỗi phiên chỉ ghi ra một đích, có duyệt. |
| KT-09 | Pomodoro và thông báo chạy local, lưu trạng thái | Khôi phục sau đóng app; đồng bộ kết quả chống trùng; tách dữ liệu theo tài khoản. |
| KT-10 | Hạn mức AI ở server | Giữ chỗ trước khi gọi, retry cùng yêu cầu không trừ thêm; hoàn hạn mức theo kết quả xử lý. Chưa thanh toán. |
| KT-11 | API + worker, job bền vững trong PostgreSQL | Cùng codebase; lease/retry hữu hạn, theo dõi trạng thái, đối chiếu thao tác ngoài khi kết quả không rõ. |
| KT-12 | SQLAlchemy + Alembic; migration dữ liệu local | Không xóa database để nâng cấp; nhập dữ liệu cũ có đồng ý, lặp lại không nhân bản. |
| KT-13 | Nghiệm thu trên Mac và tích hợp thật | Build, thử offline/xung đột, AI lỗi, Calendar thật, phân quyền và Việt/Anh. Mock không thay nghiệm thu tích hợp. |
| KT-14 | API/worker đóng gói Docker, tách môi trường | Backup và thử restore; log theo request/job ID; không log khóa, token hoặc toàn bộ context. Có thể ngắt AI mà to-do vẫn dùng được. |

### Ranh giới trách nhiệm

- iOS sở hữu giao diện, nhận dạng voice, local store/outbox, bộ đếm, local notifications và EventKit. Giữ UI hiện có trong đợt chuyển đổi.
- FastAPI sở hữu xác thực, dữ liệu chính, quyền truy cập, đồng bộ, context, hội thoại, đề xuất, thuật toán lịch, Google Calendar và quota.
- Worker thực hiện việc chậm hoặc cần retry; không giữ transaction database mở trong lúc chờ gọi AI/Google.
- Bản demo không dùng Supabase Auth/SMTP. Có thể dùng PostgreSQL managed của Supabase; app không dùng Data API để sửa trực tiếp bảng nghiệp vụ và không bỏ qua FastAPI. Khóa OpenAI chỉ ở backend dạng mã hóa; job dùng key đúng owner.
- Phân module theo trách nhiệm trên, không tạo một framework tổng quát cho mọi loại agent/tool. Chưa cần vector database, Redis hoặc framework điều phối AI bổ sung để hoàn thành baseline này.

## 13. Baseline dữ liệu và các bất biến

### 13.1. Nhóm dữ liệu chính

| Nhóm | Nội dung cần có |
|---|---|
| UserProfile | ID danh tính demo theo key (hoặc development), language `vi/en`, timezone IANA, phiên bản hồ sơ. |
| Task | UUID, owner, parent ID, thứ tự/phụ thuộc, tên/ghi chú, trạng thái, deadline, ước lượng, ưu tiên, nhóm, nhắc việc, recurrence. |
| PlannedSession | UUID, task ID, thời gian UTC, thời lượng focus/rest, trạng thái và revision kế hoạch đã duyệt. |
| FocusSession | UUID sinh trên thiết bị, task ID nếu còn tồn tại, planned session ID nếu có, tên chụp tại thời điểm học, các mốc chạy/dừng, số giây và outcome. |
| ContextFact | UUID, owner, nội dung, scope, scope ID nếu có, nguồn, trạng thái xác nhận, thời điểm ghi nhận/hiệu lực/thay thế. |
| WeeklyAvailability / DailyCommitment | Một ngày có thể có nhiều khoảng rảnh; ngân sách ngày độc lập với khoảng rảnh, gồm cả giờ nghỉ. |
| Conversation / Message | Hội thoại có mục tiêu liên quan nếu có; lượt có thứ tự, role, ngôn ngữ, job ID và trạng thái. |
| Proposal | Loại đề xuất, nội dung có cấu trúc, version, input revision/context snapshot, trạng thái duyệt và thay đổi dự kiến. |
| CalendarConnection / BusySnapshot / EventBinding | Nguồn lịch, nguồn đọc chuẩn, độ mới dữ liệu, đích ghi, liên kết phiên với sự kiện ngoài và trạng thái đồng bộ. |
| OperationReceipt / ChangeLog | Chống gửi trùng; version, tombstone và cursor cho đồng bộ. |
| Job / QuotaReservation | Công việc bền vững, lượt thử/lease; giữ chỗ, quyết toán và hoàn hạn mức. |

Đây là nhóm trách nhiệm dữ liệu, không buộc mỗi dòng phải là một bảng. Owner dữ liệu chốt schema vật lý trước migration đầu tiên. Thuộc tính ảnh hưởng truy vấn/ràng buộc có cột rõ ràng; JSONB phù hợp cho payload đề xuất, metadata và snapshot. Bản tóm tắt context là dữ liệu dẫn xuất, không thay thế ContextFact.

### 13.2. Quy tắc chung

- Dữ liệu người dùng luôn gắn với owner; lấy danh tính từ token đã xác thực. Không dùng `owner_id` app gửi để quyết định quyền.
- ID trao đổi giữa client/server là UUID ổn định, không dùng SwiftData persistent identifier hoặc số thứ tự trong một request làm ID lâu dài.
- Dữ liệu đồng bộ có `version` nguyên tăng, `updated_at` do server đặt và `deleted_at` nếu đã xóa. Không dùng đồng hồ thiết bị để quyết định bản nào thắng.
- Lưu thời điểm tuyệt đối ở UTC; trao đổi ISO 8601 có offset/Z. Giữ timezone IANA để diễn giải lịch tuần/ngày, all-day và đổi giờ mùa hè. Ngày cam kết là local date trong timezone áp dụng.
- Task `estimated_minutes` là ước lượng tổng phần việc còn cần bố trí, có nghỉ theo quy ước đã duyệt; `focus_seconds` là thời gian tập trung thực tế. Giữ lịch sử phiên để không mất dấu ước lượng cũ khi điều chỉnh.
- Phiên lịch là khối có focus/rest cụ thể, tổng thời lượng phải khớp giờ bắt đầu/kết thúc. Bộ lập lịch chia việc dài thành nhiều khối, không yêu cầu mọi việc phải vừa một khoảng trống.
- Không tự bỏ bước trước để xếp bước sau. Dependency bị chặn hoặc thiếu chỗ phải được giải thích trong kết quả chưa xếp được.
- Tạo bản kế tiếp của việc lặp là nghiệp vụ server, chống trùng theo occurrence; app có thể hiển thị pending khi offline nhưng không tự tạo bản chính thứ hai.
- FocusSession không bị mất chỉ vì task bị đổi tên/xóa; giữ snapshot và quan hệ phù hợp. Outcome phải được lưu thật, không chỉ giữ ở state màn hình.
- Tắt AI, hết quota hoặc Calendar lỗi không được chặn CRUD to-do và ghi nhận phiên offline.

### 13.3. Trạng thái quan trọng

| Đối tượng | Trạng thái baseline |
|---|---|
| Proposal | `draft → accepted / rejected / stale`; chỉnh draft tăng version; accepted không được áp dụng lần hai. |
| Job | `queued → running → succeeded / failed / cancelled`; worker bị dừng thì lease hết hạn, chỉ retry nếu chính sách cho phép. |
| Quota | `reserved → consumed / released`; unique theo yêu cầu logic, không theo mỗi lần HTTP retry. |
| Calendar write | `pending → writing → synced / retryable_error / reconnect_required / reconcile_required`; không báo synced khi chỉ gửi đi. |
| FocusSession | `running ↔ paused → finished`; outcome `done / more_time / stuck / ended`; không suy ra hoàn thành Task chỉ từ `finished`. |

## 14. Hợp đồng tích hợp giữa các nhóm

### 14.1. API chung

- Prefix `/v1`, HTTPS, JSON; token qua `Authorization: Bearer ...`. Các route không phải callback OAuth phải kiểm tra quyền trước truy vấn dữ liệu người dùng.
- App gửi `Idempotency-Key` cho lệnh tạo job, duyệt, import và ghi Calendar. Cùng key/payload trả lại cùng kết quả; cùng key nhưng payload khác trả `409`.
- Dữ liệu thay đổi gửi `expected_version`. API ghi theo transaction, trả version mới; stale trả `409` cùng dữ liệu/version hiện tại hoặc mã yêu cầu refresh.
- Lỗi có envelope thống nhất: `error.code`, `error.message`, `error.details`, `request_id`. App rẽ nhánh theo code, không phân tích chuỗi thông báo.
- Mã cơ bản: `401` cần đăng nhập/refresh, `403` không đủ quyền, `409` xung đột/stale, `422` dữ liệu sai, `429` quá hạn mức/rate, `503` dịch vụ tạm không dùng được. Token hết hạn không được retry vô hạn.
- Nội dung cho người dùng theo language; enum, field name và error code không dịch.

### 14.2. Bề mặt endpoint khởi đầu

| API | Trách nhiệm và kết quả |
|---|---|
| `POST /v1/auth/api-key` / `POST /v1/auth/refresh` | Kiểm tra key, cấp phiên và làm mới token; request chứa SecretStr, không echo khóa. |
| `GET /v1/me` | Hồ sơ, timezone, trạng thái tài khoản và thông tin khả dụng tối thiểu. |
| `POST /v1/sync/push` | Gửi operation CRUD cho dữ liệu offline được phép; trả receipt/conflict theo operation. |
| `GET /v1/sync/pull?cursor=...` | Các thay đổi theo owner, có phân trang và cursor tiếp theo; cursor không hợp lệ trả yêu cầu bootstrap lại. |
| `POST /v1/imports/local` | Nhập dữ liệu app cũ sau đồng ý; mapping ID ổn định, idempotent và có kết quả theo mục. |
| `POST /v1/conversations` | Tạo hội thoại và liên kết mục tiêu nếu có. |
| `GET /v1/conversations/{id}` | Phục hồi message, job đang chạy và proposal liên quan. |
| `POST /v1/conversations/{id}/messages` | Gửi text đã xác nhận từ text/voice, `force_proposal`, revision draft đang sửa; trả `202` với job ID. |
| `POST /v1/context/imports` | Nhận handoff, tạo job tổng hợp; không coi handoff là lệnh hệ thống. |
| `GET /v1/jobs/{id}` | Trạng thái và kết quả/lỗi của job thuộc user; app polling có backoff, phục hồi được khi mở lại. |
| `POST /v1/schedule/proposals` | Tạo đề xuất từ revision dữ liệu, date range, timezone và busy snapshot liên quan. |
| `PATCH /v1/proposals/{id}` | Sửa draft trước duyệt, kiểm tra version và tính hợp lệ. |
| `POST /v1/proposals/{id}/accept` | Kiểm tra lại version/quyền/ràng buộc; áp dụng thay đổi và đánh dấu accepted trong cùng transaction. |
| `POST /v1/proposals/{id}/reject` | Bỏ đề xuất, không đổi dữ liệu chính. |
| `POST /v1/tasks/{id}/guidance` | Tạo job hướng dẫn/tài liệu đúng lúc; hỗ trợ yêu cầu tài liệu thay thế. |
| `POST /v1/tasks/{id}/unblock` | Tạo job đề xuất cách tiếp tục; thay đổi task vẫn đi qua proposal/accept. |
| `POST /v1/calendar/eventkit/snapshots` | iOS gửi ảnh chụp khoảng bận theo thiết bị/nguồn/range; thay snapshot trong range, không cộng dồn mãi. |
| `POST /v1/calendar/google/connect` | Khởi tạo OAuth gắn với user, state và hạn dùng; callback do backend xử lý. |
| `GET /v1/calendar/google/calendars` / `PUT /v1/calendar/google/calendars` | Liệt kê có phân trang phía provider và lưu các lịch được chọn với expected version; loại lịch Etsgo đầu ra. |
| `GET /v1/calendar/status` | Trạng thái kết nối và từng lần xuất lịch; không trả OAuth token hoặc khóa. |
| `POST /v1/calendar/exports` | Ghi nhận sự đồng ý xuất revision phiên cụ thể tới một đích; tạo outbox/job và trả trạng thái. |
| `GET /v1/calendar/actions` | Thiết bị EventKit được chỉ định nhận lệnh ghi đã duyệt. |
| `POST /v1/calendar/actions/{id}/result` | Thiết bị báo kết quả, binding và attempt ID; gửi lại không tạo thêm sự kiện. |
| `GET /v1/usage` | Quota đã dùng/đang giữ chỗ/còn lại; số giới hạn lấy từ cấu hình. |

Đường dẫn callback Google, route quản lý kết nối và các field đầy đủ được owner API hoàn thiện cùng iOS trước phase tích hợp. Khi có backend, OpenAPI sinh từ schema request/response là hợp đồng thực thi; không tự tạo thêm một file schema độc lập nếu chưa nằm trong kế hoạch file.

### 14.3. Đồng bộ offline và xung đột

Operation tối thiểu gồm `operation_id`, `entity_type`, `entity_id`, `action`, `expected_version`, `payload`. Local save và outbox insert phải thành công cùng nhau. Operation đã được nhận không gửi lại bằng ID mới chỉ vì timeout.

- CRUD offline cho phép: Task, ContextFact người dùng sửa trực tiếp, lịch rảnh/cam kết và FocusSession. Không cho client sửa quota, quyền, kết quả AI, binding ngoài hoặc tự đặt proposal thành accepted qua generic sync.
- Server lưu receipt và mutation cùng transaction; mỗi operation có kết quả riêng. Operation phụ thuộc bản ghi chưa đồng bộ phải theo thứ tự; conflict ở cha giữ lại các thay đổi phụ thuộc để giải quyết, không báo đã đồng bộ cả batch.
- Tất cả đường ghi nghiệp vụ, kể cả proposal accept và kết quả worker, phải phát ChangeLog cho dữ liệu cần đồng bộ.
- Cursor là sequence theo user do server cấp trong transaction; không dựa vào timestamp. Thứ tự commit/cấp sequence phải nhất quán để client không bỏ sót thay đổi concurrent. Owner DB có thể dùng khóa transaction trên counter theo user cho baseline.
- Khi conflict, giữ payload local và bản server; người dùng chọn/sửa lại rồi gửi với expected version mới. Không dùng last-write-wins hoặc tự phục hồi bản ghi đã xóa.
- Bootstrap và pull nhiều trang cần snapshot boundary/cursor nhất quán. Không dọn tombstone/change history trước khi có chính sách hết hạn cursor và full resync.
- Đổi tài khoản: dừng worker sync local, tách kho/cursor/outbox theo user; cảnh báo pending thay đổi trước xóa cache. Không gửi dữ liệu tài khoản cũ bằng token tài khoản mới.
- Mở app/foreground/có mạng kích hoạt sync; không hứa đồng bộ EventKit tức thời khi app iOS đang bị đóng.

### 14.4. Context và AI

- Handoff → job trích xuất → ContextFact chưa xác nhận, giữ nguồn → context summary có revision. Nhập lại cùng import ID không nhân bản; nhập nội dung mới có bước đối chiếu trùng/mâu thuẫn.
- Lời người dùng nói rõ có thể tạo/cập nhật fact trong đúng scope; suy đoán giữ trạng thái riêng. Import không âm thầm thay thế fact đã xác nhận. Thông tin hết hiệu lực không được gửi như sự thật hiện tại.
- Lưu cuộc hội thoại, draft và revision tại server. App gửi text đã sửa từ voice; không cần upload audio để dùng luồng hiện tại.
- AI trả dạng phân biệt `question` hoặc `proposal`, kèm message, quick replies hoặc các bước, based-on và assumptions. Schema kiểm tra được, có giới hạn số phần tử/độ dài/thời lượng.
- Backend dựng context từ fact liên quan, trạng thái task, tiến độ, lịch/cam kết cần thiết; giới hạn kích thước prompt. Không mặc định gửi toàn bộ message và fact không giới hạn.
- Quy tắc và phân quyền nằm ngoài nội dung handoff. AI không được tự gọi SQL hoặc tự ghi Calendar.
- Model/provider cấu hình phía server; giữ lớp adapter mỏng, chọn một provider cho vòng nghiệm thu đầu rồi kiểm thử request thật trước khi tích hợp rộng. Không sao chép mù model/header tạm trong Swift hiện tại.
- Job thành công lưu output hợp lệ trước khi trả thành công. Timeout/kết quả không rõ không tự tạo một job logic mới. Retry hữu hạn có thể phát sinh chi phí provider; quota user chỉ quyết toán một lần theo yêu cầu logic.

### 14.5. Calendar

- Nguồn đọc có ID, provider, calendar/account mapping, range và `fetched_at`; nguồn ghi là Google hoặc EventKit trên một thiết bị được chỉ định. Cùng PlannedSession không xuất qua cả hai đường.
- Chỉ chọn một nguồn chuẩn khi cùng lịch Google đã xuất hiện qua EventKit. Không dựa vào tiêu đề sự kiện để nhận diện trùng. Có thể cần người dùng xác nhận mapping khi không xác định được nguồn.
- Lịch Etsgo riêng được loại khỏi external busy; các phiên đã duyệt trong app vẫn tính occupied đúng một lần. Gộp các khoảng busy chồng nhau, không cộng trùng ngân sách.
- Xử lý all-day, recurring và free/busy theo dữ liệu nguồn; không bỏ mọi all-day như code hiện tại. Khi snapshot lỗi/cũ, thể hiện thiếu dữ liệu; refresh trước duyệt nếu có thể và kiểm tra lại xung đột.
- Google OAuth token giữ phía server, mã hóa khi lưu; state gắn với user và hạn dùng, không đặt token trong log/URL trả về app. Chọn scopes hẹp: đọc calendar list/busy cần thiết và ghi lịch app tạo; không xin quyền sửa toàn bộ lịch nếu không cần.
- Baseline đọc Google busy theo khoảng cần lập lịch, refresh khi mở/đề xuất/duyệt và worker định kỳ có giới hạn. Chưa cần webhook hoặc incremental event sync cho mọi lịch cá nhân để có mốc thử nghiệm đầu.
- Chấp nhận lịch trong app và cho phép ghi lịch ngoài là hai hành động riêng. Export gắn với revision được duyệt; nếu revision đã đổi, yêu cầu duyệt lại thay vì ghi nội dung mới dưới sự đồng ý cũ.
- Ghi Google do worker thực hiện; EventKit do thiết bị nhận action thực hiện. Transaction DB chỉ ghi ý định; không thể gộp DB và API ngoài thành một transaction duy nhất.
- Binding giữ provider, calendar, external event ID và revision đã xuất. Khi request timeout phải đối chiếu trước retry; EventKit ID có thể thay đổi nên không coi ID ngoài là định danh nghiệp vụ duy nhất.
- Người dùng đổi/xóa sự kiện ngoài: đánh dấu cần đối chiếu và đề xuất, không âm thầm kéo thay đổi vào task hoặc ghi đè sự kiện người dùng vừa sửa.
- Thu hồi quyền → reconnect_required, không retry vô hạn. Ghi thất bại không được báo “đã cập nhật Lịch”.

### 14.6. Worker, quota và lỗi

- Lưu job trước khi trả `202`. Worker claim có lease, attempt ID và quyền finalize theo attempt để worker cũ không ghi kết quả muộn đè worker mới.
- Không giữ database transaction trong lúc chờ AI/Google; claim, gọi ngoài và finalize là các bước riêng.
- Quota reserve kiểm tra nguyên tử; unique theo user + logical request ID. Success quyết toán; lỗi kết thúc hoàn quota user theo chính sách. Job bị treo phải có bước reconcile reservation.
- Rate limit, giới hạn concurrency, timeout, retry/backoff và số lượt thử cấu hình được; lỗi sai quyền/dữ liệu không retry như lỗi mạng.
- Phân biệt chi phí thực tế provider và quota sản phẩm: hoàn quota cho người dùng không có nghĩa nhà cung cấp hoàn tiền.
- App polling dừng/tạm dừng đúng lifecycle và phục hồi qua job ID; không phụ thuộc một kết nối HTTP mở lâu để giữ kết quả.

## 15. Phân công để nhiều người làm song song

Các “owner” dưới đây là vai trò, chưa gán tên người và không yêu cầu đúng số người. Một người có thể giữ nhiều vai trò; chỉ định một owner tích hợp để giải quyết thay đổi hợp đồng. Không tự tạo các thư mục/file tương lai trước khi có kế hoạch triển khai được giao.

| Luồng | Owner chịu trách nhiệm | Phần việc / đầu ra | Phụ thuộc |
|---|---|---|---|
| T0 — Tích hợp và hợp đồng | Lead tích hợp | Chốt schema/enum, API envelope, version/cursor, fixture dùng chung, thứ tự migration và checklist merge. Theo dõi mọi thay đổi contract. | Bắt đầu ngay. |
| T1 — Nền backend | Backend/data | Auth, phân quyền, schema/migration, CRUD/sync, receipt/change log, import local, job/quota nền. | T0; là nền cho T2–T4. |
| T2 — AI và context | AI/backend | Import/merge/scope context, conversation/proposal, adapter AI, guidance/unblock, validate output và bộ tình huống Việt/Anh. | Hợp đồng T0; tích hợp với persistence/job/quota T1. |
| T3 — Lịch và Calendar | Scheduling/integrations | Scheduler bằng code, kiểm tra accept, Google OAuth/busy/export, binding/reconcile; contract EventKit snapshot/action. | Hợp đồng Task/PlannedSession, proposal/job của T0–T1. |
| T4 — App iOS | iOS | API/auth client, SwiftData migration, outbox/cursor/conflict, nối màn hình hiện tại, EventKit bridge, Pomodoro bền vững và nhắc việc. | T0; có thể làm với fake API theo contract trong khi T1–T3 triển khai. |
| T5 — QA và vận hành | QA/infra + người có Mac | Build sớm, test contract/integration/offline/permissions, đóng gói API/worker, môi trường test, backup/restore và kiểm tra phát hành. | Bắt đầu build baseline ngay; mở rộng theo từng lát tích hợp. |

### Bề mặt code iOS cần phối hợp

| File hiện có | Trách nhiệm khi chuyển đổi | Lưu ý tránh sửa chồng |
|---|---|---|
| `TodoList/Models/TodoItem.swift` | Migration Task/ContextFact/FocusSession và ID/version | Owner iOS giữ file; T1/T2/T3 thống nhất hợp đồng, không cùng sửa model tùy ý. |
| `TodoList/Models/StudySchedule.swift` | Lịch tuần/cam kết chuyển sang dữ liệu đồng bộ | T3 định nghĩa semantics, T4 triển khai local/API. |
| `TodoList/Services/AIService.swift` | Thay gọi Claude trực tiếp bằng API backend | Prompt/schema chuyển sang T2; app chỉ nhận contract. Không duy trì hai luồng AI chính song song lâu dài. |
| `TodoList/Services/Scheduler.swift` | Chuyển quyền lập lịch chính về backend | T3 giữ thuật toán server, T4 thay call site; không chạy hai thuật toán cho cùng một lịch duyệt. |
| `TodoList/Services/CalendarService.swift` | Bridge EventKit, snapshot và action đã duyệt | T4 sở hữu thao tác iOS; T3 sở hữu contract/binding. |
| `TodoList/Views/PlannerView.swift`, `ContextView.swift` | Nối hội thoại/draft/context server | Giữ trải nghiệm hiện có; bỏ vai trò nguồn dữ liệu chính của `@State`. |
| `TodoList/Views/ScheduleView.swift` | Proposal/accept/export backend, revision và trạng thái thật | Không tiếp tục quyết định ghi dữ liệu chính trực tiếp trong View. |
| `TodoList/Views/PomodoroView.swift`, `Services/NotificationService.swift` | Lưu/khôi phục phiên và đồng bộ outcome | Timer vẫn local; T4 phụ trách, T5 kiểm thử kill/relaunch/background. |
| `TodoList/TodoListApp.swift`, `Views/OnboardingView.swift`, `Views/SettingsView.swift` | Auth, lifecycle sync, migration và cấu hình | Chỉ một owner iOS điều phối thay đổi entry point/project. |

### Quy tắc phối hợp

- Mỗi task triển khai có owner, ID yêu cầu/KT liên quan, file được phép đổi, phụ thuộc và tiêu chí hoàn thành. Chưa có danh sách file thì lập kế hoạch trước khi tạo thêm.
- Một người chịu trách nhiệm migration/schema và một người chịu trách nhiệm entry point/project iOS; các bên khác đề xuất thay đổi qua họ.
- Tách branch theo phần việc, PR nhỏ và tham chiếu contract; không sửa trực tiếp nhánh teammate đang làm. Không tự merge code chưa review chỉ vì test riêng lẻ qua.
- Thay đổi field/enum/endpoint phải cập nhật producer, consumer và test contract cùng kế hoạch; không để phía app/backend tự diễn giải khác nhau.
- Có thể dùng fake provider/API đúng contract để làm song song; phải ghi rõ trạng thái fake và thay bằng tích hợp thật trước nghiệm thu.
- Không tự suy ra đã được phép spawn agent hoặc chạy việc song song chỉ từ bảng phân công. Người điều phối giao đầu việc cụ thể cho người/agent đang có.
- Bàn giao ghi commit gốc, file thay đổi, migration/config cần chạy, kiểm tra đã chạy, hạn chế và phần còn chờ bên khác. Không ghi secret vào tài liệu/PR.

## 16. Thứ tự tích hợp và điều kiện hoàn thành

| Phase | Kết quả phải có trước khi đi tiếp |
|---|---|
| P0 — Chốt baseline | Build code iOS `aa9f237` trên Mac; ghi lỗi thực tế. Chốt T0, nhóm file triển khai và cấu hình môi trường. Không coi README là bằng chứng build qua. |
| P1 — Dữ liệu và offline | Đăng nhập thật; Task local/server; import có đồng ý; offline CRUD/outbox; idempotency, tombstone, conflict và phân quyền được test. |
| P2 — AI và context | Handoff/context/hội thoại lưu server; job/quota; question/proposal; duyệt tạo việc; đóng app vẫn phục hồi; cả Việt/Anh và lỗi AI. |
| P3 — Lịch và hai nguồn | PlannedSession riêng; scheduler theo commitment/dependency; EventKit và Google thật; proposal accept kiểm tra lại; export một đích và đối chiếu kết quả không rõ. |
| P4 — Thực hiện | Pomodoro local bền vững, notifications, outcome/task linkage, guidance/unblock, recurrence/nhắc việc không tạo trùng. |
| P5 — Nghiệm thu đầu | Luồng đầu-cuối trên iPhone với backend test; dữ liệu không mất khi offline/restart, quota đúng, backup restore thử thành công; chưa thanh toán. |

T2/T3/T4/T5 có thể phát triển song song sau khi hợp đồng T0 ổn định; bảng phase chỉ quy định thứ tự tích hợp/nghiệm thu, không buộc cả nhóm chờ nhau viết xong toàn bộ.

### Kiểm tra quyết định chất lượng

- Backend: dùng PostgreSQL thật cho test transaction/concurrency/sync, không thay toàn bộ bằng SQLite; kiểm tra hai người dùng không truy cập chéo.
- Đồng bộ: cùng operation gửi nhiều lần; timeout sau server commit; tạo cha/con offline; sửa/xóa concurrent; nhiều trang pull có ghi concurrent; đổi tài khoản còn outbox.
- AI: provider thật cho smoke test schema; fake có chủ đích cho refusal, malformed output, timeout và retry; kiểm tra proposal cũ không ghi đè task/context mới.
- Lịch: busy chồng nhau, commitment 0, nhiều khung rảnh, dependency bị chặn, task dài chia nhiều phiên, deadline bất khả thi, timezone/DST/all-day; duyệt khi busy snapshot đã đổi.
- Calendar thật: cả EventKit/Google, cùng lịch hiện hai nguồn, hết quyền, sửa/xóa bên ngoài, timeout sau tạo event và thử lại; không trùng event, không ghi sai revision.
- Pomodoro trên Mac/iPhone: pause/resume, background, kill/relaunch, đóng sớm, offline và sync lại; không cộng thời gian/hoàn thành việc hai lần. Kiểm tra outcome được lưu và start time là thời điểm thực tế.
- Migration: dữ liệu cũ được giữ; import lặp không trùng; lỗi giữa chừng có thể tiếp tục. Nâng schema không yêu cầu xóa dữ liệu người dùng.
- Vận hành: worker chết/lease hết hạn, quota reservation treo, tắt AI, log không chứa secret/context nguyên văn; thử restore từ backup và chạy lại smoke test.

Definition of Done cho mỗi phần: có mã và migration cần thiết, contract cập nhật, kiểm tra liên quan qua, ghi rõ bằng chứng/lỗi còn lại và được consumer tích hợp. Với mốc P5, cần người có Mac xác nhận build và các ca thiết bị thật; hiện tài liệu này chưa ghi nhận các kiểm tra đó đã chạy.

## 17. Nguồn kỹ thuật và điểm còn phải chốt

Nguồn chính thức đã tham khảo khi chọn thiết kế (cần kiểm tra lại phiên bản khi triển khai):

- [FastAPI: features và OpenAPI](https://fastapi.tiangolo.com/features/).
- [PostgreSQL: JSON/JSONB](https://www.postgresql.org/docs/current/datatype-json.html).
- [OpenAI API quickstart](https://developers.openai.com/api/docs/quickstart): key dùng phía backend. Quyết định email OTP cũ đã được người sáng lập thay bằng nhập key cho bản demo.
- [SQLAlchemy](https://docs.sqlalchemy.org/), [Alembic migrations](https://alembic.sqlalchemy.org/en/latest/).
- [Anthropic Python SDK](https://platform.claude.com/docs/en/cli-sdks-libraries/sdks/python): tham khảo adapter, không cam kết provider/model cuối.
- [Google Calendar scopes](https://developers.google.com/workspace/calendar/api/auth), [Freebusy](https://developers.google.com/workspace/calendar/api/v3/reference/freebusy/query), [xử lý lỗi](https://developers.google.com/workspace/calendar/api/guides/errors).
- [Apple EventKit eventIdentifier](https://developer.apple.com/documentation/eventkit/ekevent/eventidentifier): ID có thể đổi khi chuyển calendar; không dùng như ID nghiệp vụ duy nhất.

Trước khi tạo code mới: người điều phối gán owner thực tế, chốt kế hoạch file, schema/OpenAPI baseline và thứ tự migration. Trước tích hợp thật: chọn model/provider, giá trị hạn mức, secret phiên/mã hóa, cấu hình OAuth/scopes/redirect và tiêu chí độ mới busy. Trước đưa người dùng thật vào: chốt chính sách dữ liệu, backup/restore, giới hạn ngân sách và điều kiện thử nghiệm cho người chưa thành niên. Không cần chờ chốt giá thanh toán để làm mốc kỹ thuật đầu.
