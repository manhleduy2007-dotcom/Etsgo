# Etsgo — Đặc tả sản phẩm MVP

Ngày lập: 14/11/2026. Ngôn ngữ tài liệu: tiếng Việt.

Tài liệu tổng hợp các quyết định sản phẩm đã được người sáng lập duyệt trong hội thoại. Các mục ghi “chưa chốt” hoặc “đề xuất triển khai” chưa phải yêu cầu đã duyệt. Đây là đặc tả sản phẩm, chưa quyết định kiến trúc, nhà cung cấp AI hay phương thức kết nối từng dịch vụ.

Mô hình kinh doanh đi kèm: [BUSINESS_MODEL_CANVAS.md](BUSINESS_MODEL_CANVAS.md).

Agent tiếp nhận công việc: đọc mục 11 trước, sau đó đọc mục 3–6 và tiêu chí nghiệm thu tại mục 8. Phân biệt context bàn giao dự án với context cá nhân của người dùng được mô tả trong sản phẩm.

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
- Cách hiểu “cam kết 2 giờ” có bao gồm nghỉ hay không chưa được chốt; cần quyết định và thể hiện nhất quán trước triển khai bộ lập lịch.
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

## 10. Quyết định còn mở trước triển khai

1. Chọn nguồn lịch đầu tiên và phương thức nhận dữ liệu. Google Calendar, Notion Calendar và nguồn khác là nhu cầu đầu vào; chưa cam kết mọi nguồn có cùng khả năng kết nối hoặc đồng bộ.
2. Chốt phạm vi ghi lịch ngoài và xử lý cập nhật/xung đột; mọi ghi thay đổi đều giữ cơ chế duyệt.
3. Chọn mô hình AI, nhận dạng voice, cơ chế lấy tài liệu và tiêu chí kiểm thử Việt/Anh.
4. Chốt quy ước commitment có/không bao gồm giờ nghỉ.
5. Chốt hạn mức miễn phí, quyền lợi trả phí và giá dựa trên chi phí và thử nghiệm.
6. Chốt chính sách lưu/xóa context, dữ liệu lịch, voice và yêu cầu áp dụng cho người dùng chưa thành niên.
7. Chọn nền tảng mobile phát hành đầu tiên và yêu cầu chạy bộ đếm/thông báo khi app ở nền.

Các điểm này cần nghiên cứu hoặc quyết định riêng; không thay đổi mục tiêu và phạm vi sản phẩm đã duyệt ở trên.

## 11. Bàn giao context cho các agent phát triển

### 11.1. Trạng thái và nguồn quyết định

Tại lần bàn giao ngày 14/11/2026, repository đã được kiểm tra chỉ có README và hai tài liệu sản phẩm này; chưa có mã ứng dụng, stack kỹ thuật, tích hợp đã chạy hoặc kết quả thử nghiệm người dùng. Đây là mốc bàn giao tài liệu, không phải MVP đã triển khai. Agent tiếp theo phải kiểm tra checkout thực tế vì trạng thái repository có thể đã thay đổi.

- Tài liệu này là nguồn mô tả phạm vi và hành vi sản phẩm; Business Model Canvas bổ sung định hướng thương mại.
- Quyết định mới, rõ ràng của người dùng có ưu tiên so với nội dung cũ. Nếu hai tài liệu mâu thuẫn mà chưa có quyết định mới, nêu mâu thuẫn thay vì tự xem giả định là yêu cầu đã duyệt.
- Các mục “chưa chốt”, mẫu prompt, kế hoạch kiểm chứng và đề xuất kỹ thuật không được hiểu thành cam kết đã được kiểm thử hoặc xác nhận khả thi.
- Tuân thủ chỉ dẫn của người dùng: **không tự tiện bổ sung file ngoài kế hoạch nếu không được chỉ dẫn**. Bàn giao hiện tại chỉ gồm `MVP_SPEC.md` và `BUSINESS_MODEL_CANVAS.md`; chưa phải sự cho phép tạo bộ khung ứng dụng, dependency hoặc tài liệu bổ sung. Khi được giao triển khai, thống nhất phạm vi file theo công việc được giao trước khi tạo thêm.

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
| Kinh doanh | Freemium: to-do cơ bản miễn phí, hạn mức AI cho trải nghiệm giá trị cá nhân hóa; trả phí mở rộng sử dụng. Giá/hạn mức chưa chốt. |
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
