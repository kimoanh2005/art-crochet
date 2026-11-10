chạy bằng file run.ps1 thì câu lệnh chạy là: .\run.ps1

# Đặc tả kỹ thuật — Art Crochet

## 1. Tổng quan

| Thuộc tính | Mô tả |
|---|---|
| Tên hiển thị | Art Crochet |
| Package Flutter | `crochet_charts` |
| Mục đích | Thiết kế, quản lý chart móc len và theo dõi tiến độ |
| Client | Flutter/Dart (Android và các nền tảng Flutter khác) |
| Backend | Supabase Auth và PostgreSQL |
| Ngôn ngữ giao diện | Tiếng Việt |

Ứng dụng yêu cầu tài khoản đăng nhập. Dữ liệu nghiệp vụ được tải/lưu qua
Supabase; không dùng demo hoặc bộ nhớ cục bộ làm nguồn dữ liệu dự phòng.

## 2. Công nghệ và phụ thuộc

- Flutter với ràng buộc Dart SDK `^3.9.0`.
- `supabase_flutter`: Auth, truy vấn PostgreSQL và gọi RPC.
- `pdf`: dựng tài liệu PDF.
- `printing`: xem trước, in và chia sẻ PDF.
- `path_provider`, `share_plus`: hỗ trợ các thao tác tệp/chia sẻ.
- `flutter_test`, `flutter_lints`: kiểm thử và lint.

## 3. Kiến trúc mã nguồn

```text
lib/
├── main.dart                  # Kiểm tra cấu hình và khởi tạo Supabase
├── app.dart                   # MaterialApp, điều hướng và trạng thái gốc
├── core/                      # Màu, hằng số, theme
├── models/                    # Chart, loại mũi, hồ sơ, màu, PDF
├── screens/
│   ├── auth/                  # Đăng nhập và đăng ký
│   ├── charts/                # CRUD, thiết kế, chi tiết, hướng dẫn, PDF
│   ├── home/
│   ├── profile/
│   └── progress/
├── services/
│   ├── crochet_api.dart      # Auth và truy cập Supabase
│   └── pdf_export_service.dart
├── state/app_state.dart       # Nạp dữ liệu và cập nhật trạng thái ứng dụng
└── widgets/                   # Điều hướng và widget dùng chung
```

`main.dart` đọc `SUPABASE_URL` và `SUPABASE_PUBLISHABLE_KEY` từ compile-time
environment. Thiếu một trong hai giá trị thì ứng dụng hiển thị hướng dẫn cấu
hình và không khởi chạy dữ liệu demo. `AppState` theo dõi sự kiện Auth, tải dữ
liệu người dùng và chuyển thao tác từ UI tới `CrochetApi`.

## 4. Chức năng

### 4.1. Tài khoản và hồ sơ

- Tạo tài khoản email/mật khẩu, đăng nhập và đăng xuất.
- Đăng ký có thể cần xác nhận email tùy cài đặt Supabase Auth.
- Đọc/cập nhật tên hiển thị, email và phần giới thiệu.
- Dữ liệu người dùng bị xóa khỏi trạng thái ứng dụng khi đăng xuất.

### 4.2. Chart

- Tạo chart với tên, danh mục, mô tả, số hàng/vòng, số cột/mũi và loại chart.
- Kích thước hàng và cột được giới hạn từ 2 tới 50.
- Tìm kiếm theo tên, lọc danh mục/loại, đánh dấu yêu thích, sao chép và xóa.
- Lưu nội dung thiết kế và tiến độ qua Supabase.

### 4.3. Các kiểu thiết kế

1. `pixel`: lưới ô; mỗi ô lưu vị trí hàng/cột, loại mũi và màu.
2. `stitch_symbols`: ký hiệu mũi đặt tự do trên mặt phẳng, tổ chức theo hàng.
3. `circular`: ký hiệu tự do theo vòng; mặt phẳng có hướng dẫn căn tâm/vòng.

Hai kiểu ký hiệu tự do lưu tọa độ chuẩn hóa từ `0.0` tới `1.0`, chỉ mục hàng/
vòng và thứ tự ký hiệu. Trình thiết kế hỗ trợ chọn màu/loại mũi, thao tác vẽ,
chọn, di chuyển, xóa, hoàn tác/làm lại và ghi chú từng hàng/vòng. Không suy diễn
hướng móc hoặc tự sinh công thức móc từ chart Pixel.

### 4.4. Tiến độ, màu và PDF

- Trạng thái chart: `not_started`, `in_progress`, `completed`.
- Tiến độ lưu số hàng/vòng hoàn tất, đơn vị hiện tại và ghi chú.
- Người dùng có thể thêm, sửa, xóa màu len (tên, mã hex, thương hiệu, mã sợi).
- PDF hiển thị thông tin chart, nội dung, chú giải màu/ký hiệu và ghi chú; có
  xem trước, in và chia sẻ. Chưa hỗ trợ xuất PNG.

### 4.5. Giao diện

- Điều hướng tới Trang chủ, Chart của tôi, Thiết kế chart, Tiến độ móc và Cá nhân.
- Màn hình phụ gồm xác thực, tạo chart, trình thiết kế, chi tiết, hướng dẫn và
  quản lý màu len.
- Bố cục đáp ứng kích thước màn hình; điều hướng dưới dành cho viewport hẹp,
  trình thiết kế dùng thanh công cụ gọn trên mobile và vùng an toàn của hệ điều
  hành.
- Các form có thể cuộn trên màn hình thấp/hẹp; lưới chart hỗ trợ phóng to/thu
  nhỏ và kéo xem trên màn hình cảm ứng.

## 5. Lược đồ Supabase

Migration trong `supabase/migrations/` cần được chạy theo thứ tự tên tệp:

1. `20261027000000_initial_schema.sql`
2. `20261027000001_chart_type_freeform_design.sql`

Các bảng nghiệp vụ:

| Bảng | Vai trò |
|---|---|
| `profiles` | Hồ sơ gắn với `auth.users` |
| `charts` | Metadata chart, kích thước, loại, yêu thích |
| `stitch_types` | Danh mục mũi móc dùng chung; migration seed 5 loại mũi |
| `chart_colors` | Màu gắn với thiết kế Pixel |
| `chart_cells` | Ô Pixel và loại mũi/màu |
| `chart_sections` | Chỉ dẫn theo hàng/vòng của chart ký hiệu |
| `chart_stitches` | Ký hiệu tự do, tọa độ, loại mũi và màu |
| `chart_progress` | Tiến độ và ghi chú theo chart/tài khoản |
| `chart_exports` | Metadata tệp xuất, nếu luồng lưu export được sử dụng |
| `yarn_colors` | Danh mục màu len cá nhân |

Các quan hệ chart dùng khóa ngoại và cascade delete theo schema. Migration bật RLS
cho bảng dữ liệu và giới hạn thao tác theo `auth.uid()`/chủ sở hữu chart. RPC
`save_chart_design` lưu thiết kế Pixel; `save_chart_stitches` lưu thiết kế ký
hiệu và các hàng/vòng. Client dùng publishable key; không đặt service-role key
trong ứng dụng.

## 6. Cấu hình và chạy

Sau khi clone và chạy `flutter pub get`, triển khai hai migration lên Supabase
project. Lấy URL và publishable key của project, sau đó chạy:

```powershell
flutter run -d chrome `
  --dart-define="SUPABASE_URL=https://YOUR_PROJECT.supabase.co" `
  --dart-define="SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY"
```

Thay giá trị mẫu bằng cấu hình của môi trường sử dụng. Không commit thông tin
secret. Hướng dẫn clone đầy đủ nằm trong [README.md](./README.md).

### Cài thử trên thiết bị Android

Bật USB debugging, kết nối thiết bị, xác nhận `flutter devices`, sau đó dùng
`flutter run -d <ANDROID_DEVICE_ID>` cùng hai `--dart-define` ở trên. Để tạo APK
debug cài thử, chạy `flutter build apk --debug` với cùng hai giá trị cấu hình.
Tệp đầu ra là `build\app\outputs\flutter-apk\app-debug.apk`. APK debug không
phải bản phát hành Google Play; phát hành cần application ID và khóa ký release
riêng. Build iOS yêu cầu macOS/Xcode.

## 7. Kiểm thử

```powershell
flutter analyze
flutter test
```

Các kiểm thử hiện có bao gồm màn hình báo thiếu cấu hình Supabase, điều hướng,
đăng nhập và form tạo chart tại viewport hẹp, cùng tính toán tiến độ/đơn vị
chart. Cần bổ sung kiểm thử tích hợp với Supabase và kiểm tra thủ công trên
thiết bị mục tiêu trước khi phát hành.
