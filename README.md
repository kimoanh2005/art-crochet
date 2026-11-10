# Art Crochet

Art Crochet là ứng dụng Flutter giúp thiết kế và quản lý chart móc len, lưu màu
len cá nhân và theo dõi tiến độ thực hiện từng hàng hoặc vòng. Ứng dụng sử dụng
Supabase để xác thực và đồng bộ dữ liệu giữa các phiên đăng nhập.

## Công nghệ

- Flutter và Dart (Dart SDK `^3.9.0`).
- Supabase Auth và PostgreSQL thông qua `supabase_flutter`.
- `pdf` và `printing` để xem trước, in hoặc chia sẻ chart PDF.
- Các gói hỗ trợ: `path_provider`, `share_plus`.

## Tính năng

- Đăng ký, đăng nhập và đăng xuất bằng Supabase Auth.
- Tạo, chỉnh sửa, sao chép, tìm kiếm, yêu thích và xóa chart.
- Ba kiểu chart: Pixel, ký hiệu mũi móc tự do và chart tròn.
- Chọn ký hiệu/màu len; vẽ, chọn, di chuyển, xóa, hoàn tác và làm lại trong
  trình thiết kế.
- Ghi chú theo hàng/vòng, theo dõi tiến độ, quản lý hồ sơ và danh mục màu len.
- Xem trước, in và chia sẻ chart dưới dạng PDF. Chưa có xuất PNG.

## Clone và cài đặt

Yêu cầu: Git, Flutter SDK tương thích với `pubspec.yaml`, Android SDK/Android
Studio (để build Android), cùng tài khoản Supabase có quyền cấu hình project.
Chrome chỉ cần nếu muốn chạy bản web.

```powershell
git clone https://github.com/<OWNER>/<REPOSITORY>.git D:\art-crochet
Set-Location D:\art-crochet
flutter pub get
```

Thay `<OWNER>/<REPOSITORY>` bằng địa chỉ repository thực tế. Nếu thư mục clone
có tên khác, hãy chuyển vào đúng thư mục đó. Trên Windows, nên dùng đường dẫn
chỉ gồm ký tự ASCII (ví dụ `D:\art-crochet`) để tránh giới hạn đường dẫn của
Android Gradle. Dự án bật `android.overridePathCheck` để hỗ trợ workspace hiện
tại có đường dẫn tiếng Việt; nếu build vẫn lỗi, hãy clone/chuyển dự án sang một
đường dẫn ASCII.

## Cấu hình Supabase và chạy

Ứng dụng cần `SUPABASE_URL` và `SUPABASE_PUBLISHABLE_KEY` lúc khởi động. Tạo
project Supabase của bạn, sau đó chạy lần lượt hai migration dưới đây trên đúng
database:

1. `supabase/migrations/20261027000000_initial_schema.sql`
2. `supabase/migrations/20261027000001_chart_type_freeform_design.sql`

Lấy URL và publishable key từ phần cấu hình API của project. Không dùng hoặc
đưa `service_role`/secret key vào ứng dụng Flutter hay repository.

### Chạy trên điện thoại Android

1. Cài Android Studio/Android SDK và chấp nhận Android SDK licenses bằng
   `flutter doctor --android-licenses`.
2. Trên điện thoại, bật **Developer options** và **USB debugging**, kết nối
   điện thoại với máy tính và chấp nhận hộp thoại cấp quyền gỡ lỗi.
3. Kiểm tra thiết bị được nhận diện:

```powershell
flutter devices
```

Chạy ứng dụng trực tiếp lên điện thoại, thay `<ANDROID_DEVICE_ID>` cùng các giá
trị Supabase bằng cấu hình của bạn:

```powershell
flutter run -d <ANDROID_DEVICE_ID> `
  --dart-define="SUPABASE_URL=https://YOUR_PROJECT.supabase.co" `
  --dart-define="SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY"
```

Để tạo APK debug có thể cài thử trên điện thoại:

```powershell
flutter build apk --debug `
  --dart-define="SUPABASE_URL=https://YOUR_PROJECT.supabase.co" `
  --dart-define="SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY"
```

APK được tạo tại `build\app\outputs\flutter-apk\app-debug.apk`. Có thể cài qua
USB với Android Platform Tools:

```powershell
adb install -r .\build\app\outputs\flutter-apk\app-debug.apk
```

APK debug phù hợp cho cài đặt/kiểm thử cá nhân, không dùng để phát hành lên
Google Play. Trước khi phát hành, cần cấu hình application ID riêng và khóa ký
release an toàn theo hướng dẫn Flutter/Android; không dùng khóa debug để phát
hành. Build iOS cần macOS và Xcode.

### Chạy ứng dụng web

Chạy web từ PowerShell, thay các giá trị mẫu bằng thông tin project:

```powershell
flutter run -d chrome `
  --dart-define="SUPABASE_URL=https://YOUR_PROJECT.supabase.co" `
  --dart-define="SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY"
```

Không có dữ liệu demo khi chưa cấu hình Supabase hoặc khi tải dữ liệu lỗi; ứng
dụng sẽ báo lỗi thay vì giả lập lưu thành công.

## Kiểm tra

```powershell
flutter analyze
flutter test
```

## Cấu trúc chính

```text
lib/
  core/       Hằng số và giao diện/theme
  models/     Mô hình chart, mũi móc, hồ sơ, màu và dữ liệu PDF
  screens/    Màn hình xác thực, chart, tiến độ và hồ sơ
  services/   Tích hợp Supabase và tạo PDF
  state/      Trạng thái phiên và dữ liệu ứng dụng
  widgets/    Thành phần giao diện dùng chung
supabase/
  migrations/ Schema và RPC của cơ sở dữ liệu
test/         Widget test và kiểm thử model
```

Xem [PROJECT_SPEC.md](./PROJECT_SPEC.md) về đặc tả kỹ thuật và
[final.md](./final.md) về tổng kết kết quả thực hiện.
