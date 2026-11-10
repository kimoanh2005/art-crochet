# Tổng kết kết quả thực hiện đồ án — Art Crochet

## 1. Giới thiệu

**Art Crochet** là ứng dụng hỗ trợ người dùng thiết kế, lưu trữ và quản lý chart
móc len. Người dùng có thể làm việc với chart Pixel, chart ký hiệu mũi móc hoặc
chart tròn; lưu dữ liệu theo tài khoản Supabase; và ghi nhận tiến độ móc.

## 2. Kết quả và tính năng đã thực hiện

### Tài khoản và dữ liệu

- Tích hợp đăng ký, đăng nhập, đăng xuất bằng Supabase Auth; hỗ trợ trường hợp
  project yêu cầu xác nhận email.
- Tải hồ sơ, chart, màu len và danh mục mũi móc từ Supabase sau khi đăng nhập.
- Thao tác dữ liệu đi qua `CrochetApi`; không dùng dữ liệu mẫu làm nguồn thay thế
  khi kết nối thất bại. Có hiển thị lỗi khởi tạo/tải dữ liệu và cho phép thử lại.
- Hồ sơ có tên hiển thị, email và phần giới thiệu; chart và màu len được quản lý
  theo tài khoản.

### Chart và trình thiết kế

- Tạo chart với tên, danh mục, mô tả, kích thước và kiểu thiết kế.
- Quản lý chart: tìm kiếm, yêu thích, sao chép, chỉnh sửa và xóa.
- Hỗ trợ ba kiểu:
  - **Pixel:** thiết kế theo ô trên lưới.
  - **Ký hiệu mũi móc:** đặt ký hiệu tự do trên mặt phẳng.
  - **Chart tròn:** bố trí ký hiệu tự do theo các vòng với hướng dẫn căn tâm.
- Chọn loại mũi và màu; đặt, chọn, di chuyển, xóa ký hiệu/ô; hoàn tác và làm
  lại thay đổi trong phiên thiết kế.
- Lưu ghi chú theo hàng/vòng và thông tin thiết kế lên Supabase.

### Theo dõi và xuất

- Theo dõi trạng thái chưa bắt đầu/đang thực hiện/hoàn thành, số hàng hoặc vòng
  đã hoàn tất và tiến độ chart.
- Quản lý màu len theo tên, mã màu, thương hiệu và mã sợi.
- Tạo bản xem trước PDF, hỗ trợ in hoặc chia sẻ PDF.

### Giao diện

- Có các màn hình đăng nhập/đăng ký, Trang chủ, Chart của tôi, Tạo chart, Trình
  thiết kế, Chi tiết chart, Hướng dẫn móc, Tiến độ, Cá nhân và Quản lý màu len.
- Bố cục thích ứng theo kích thước màn hình, có điều hướng dọc trên màn hình
  rộng và thanh điều hướng dưới trên điện thoại.
- Các form và điều hướng được kiểm tra ở viewport điện thoại hẹp 320 × 640;
  trình thiết kế giữ nội dung trong vùng an toàn của thiết bị.
- Có cấu hình quyền Internet trên Android để kết nối Supabase; README hướng dẫn
  chạy trực tiếp trên thiết bị và tạo APK debug để cài thử.
- Giao diện tiếng Việt với phong cách màu pastel, nhẹ nhàng.

## 3. Công nghệ và kiến trúc

- Flutter/Dart cho giao diện và ứng dụng đa nền tảng.
- Supabase Auth để xác thực; Supabase PostgreSQL, RLS và RPC để quản lý dữ liệu.
- Tách phần giao diện, model, `AppState` và `CrochetApi`.
- Các gói chính: `supabase_flutter`, `pdf`, `printing`, `path_provider`,
  `share_plus`.
- Hai migration SQL tạo schema, chính sách truy cập và lưu thiết kế.

## 4. Giới hạn và công việc cần lưu ý

- Chưa có chức năng xuất PNG.
- Cần triển khai hai migration trên Supabase project và cấu hình đúng URL,
  publishable key, chính sách Auth/email trước khi sử dụng.
- Chưa khẳng định ứng dụng đã được phát hành hoặc kiểm thử trên mọi thiết bị;
  cần kiểm tra thêm trên thiết bị mục tiêu và môi trường Supabase thực tế.
- APK debug chỉ dùng cài thử; phát hành Google Play cần application ID và khóa
  ký release riêng. Build iOS yêu cầu macOS/Xcode.
- Khả năng in/chia sẻ PDF phụ thuộc nền tảng và dịch vụ in/chia sẻ trên thiết bị.

## 5. Kiểm tra dự án

```powershell
flutter analyze
flutter test
```

Kiểm thử Flutter đã chạy thành công (5/5). Phân tích mã không có lỗi nghiêm
trọng; còn 3 thông báo lint mức info ở mã hiện có. APK Android chưa xác nhận
build được trong workspace này: đường dẫn có ký tự tiếng Việt gây lỗi Kotlin
incremental cache, đồng thời Gradle gặp lỗi TLS khi tải một dependency. Nên
clone dự án vào đường dẫn ASCII và thử build lại khi Maven Central truy cập được.

## 6. Kết luận

Đồ án đã xây dựng được luồng chính của một ứng dụng thiết kế và quản lý chart
móc len: xác thực người dùng, CRUD chart, ba kiểu thiết kế, lưu màu và ghi chú,
theo dõi tiến độ và xuất PDF. Tài liệu cấu hình chạy và đặc tả chi tiết nằm ở
[README.md](./README.md) và [PROJECT_SPEC.md](./PROJECT_SPEC.md).
