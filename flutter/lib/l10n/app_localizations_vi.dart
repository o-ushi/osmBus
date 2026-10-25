// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'osmBus';

  @override
  String get settings => 'Cài đặt';

  @override
  String get reload => 'Tải lại';

  @override
  String get cancel => 'Hủy';

  @override
  String get ok => 'OK';

  @override
  String get never => 'Chưa có';

  @override
  String get destinationUnset => 'Đặt điểm đến';

  @override
  String get destinationLabel => 'Điểm đến';

  @override
  String get destinationPickedPoint => 'Điểm chọn trên bản đồ';

  @override
  String get tableConsentRequired => 'Đồng ý dùng dữ liệu OSM để xem tuyến';

  @override
  String get noLocation => 'Chưa có vị trí hiện tại';

  @override
  String get tableCalculating => 'Đang tải tuyến…';

  @override
  String get tableNoRoutes =>
      'Không tìm thấy tuyến với điều kiện này. Kiểm tra vị trí, điểm đến và dữ liệu tuyến.';

  @override
  String get noRouteData => 'Chưa có dữ liệu tuyến';

  @override
  String get headerDirection => 'Hướng';

  @override
  String get headerDirect => 'Đi thẳng';

  @override
  String get headerTransfer1 => 'Chuyển 1';

  @override
  String get headerTransfer2 => 'Chuyển 2+';

  @override
  String transferCount(String count) {
    return 'Chuyển $count';
  }

  @override
  String get compassN => 'Bắc';

  @override
  String get compassNE => 'Đông Bắc';

  @override
  String get compassE => 'Đông';

  @override
  String get compassSE => 'Đông Nam';

  @override
  String get compassS => 'Nam';

  @override
  String get compassSW => 'Tây Nam';

  @override
  String get compassW => 'Tây';

  @override
  String get compassNW => 'Tây Bắc';

  @override
  String get enterBusNumber => 'Nhập số xe buýt';

  @override
  String boardVariant(String names) {
    return 'Nếu là $names thì lên xe!';
  }

  @override
  String get doNotBoard => 'Bỏ qua xe này!';

  @override
  String alightAt(String stop) {
    return 'Xuống tại $stop';
  }

  @override
  String estimatedArrival(String time, int minutes) {
    return 'Đến khoảng $time (ước tính, ~$minutes phút)';
  }

  @override
  String get directionAny => 'Cả hai hướng đều được nếu đi về phía điểm đến';

  @override
  String directionToward(String direction) {
    return 'Thường hướng $direction — không bắt buộc';
  }

  @override
  String get keypadDelete => 'Xóa';

  @override
  String get keypadSubmit => 'Kiểm tra';

  @override
  String ridingNow(String ref) {
    return 'Đang đi: $ref';
  }

  @override
  String get endRiding => 'Kết thúc chuyến';

  @override
  String get sectionData => 'Dữ liệu tuyến';

  @override
  String get consentTitle => 'Dùng dữ liệu OpenStreetMap';

  @override
  String get consentDescription =>
      'Lấy các tuyến xe buýt lân cận từ Overpass API và lưu trên thiết bị.';

  @override
  String get withdrawConsent => 'Rút lại đồng ý và xóa dữ liệu';

  @override
  String get withdrawConfirm => 'Thao tác này xóa tệp tuyến đã lưu. Tiếp tục?';

  @override
  String routeCount(int count) {
    return '$count tuyến';
  }

  @override
  String geometryCount(int count) {
    return '$count có hình dạng';
  }

  @override
  String lastSaved(String time) {
    return 'Lưu lần cuối $time';
  }

  @override
  String get downloadAll => 'Tải tất cả';

  @override
  String get updateRoutes => 'Cập nhật';

  @override
  String progress(int done, int total) {
    return 'Đang tải $done/$total';
  }

  @override
  String downloadFinished(int count) {
    return 'Đã lưu $count tuyến có hình dạng';
  }

  @override
  String updateFinished(int count) {
    return 'Đã cập nhật ($count tuyến có hình dạng)';
  }

  @override
  String get downloadNoRoutes => 'Không có tuyến lân cận';

  @override
  String get downloadConsentRequired => 'Cần đồng ý dùng dữ liệu OSM';

  @override
  String downloadFailed(String detail) {
    return 'Tải thất bại: $detail';
  }

  @override
  String get needsLocation => 'Cần vị trí hiện tại để tải';

  @override
  String get sectionBackup => 'Sao lưu';

  @override
  String get exportBackup => 'Xuất';

  @override
  String get importBackup => 'Nhập';

  @override
  String get importChooseMode => 'Cách nhập';

  @override
  String get importReplace => 'Thay thế';

  @override
  String get importMerge => 'Gộp';

  @override
  String importDone(int count) {
    return 'Đã lưu $count tuyến';
  }

  @override
  String importFailed(String reason) {
    return 'Không nhập được: $reason';
  }

  @override
  String get sectionSync => 'Đồng bộ';

  @override
  String get iCloudSync => 'Đồng bộ iCloud';

  @override
  String get iCloudOnlyIOS => 'iCloud chỉ có trên iOS';

  @override
  String get iCloudUnavailable =>
      'Không dùng được iCloud (chưa đăng nhập hoặc chưa thiết lập container)';

  @override
  String get syncNow => 'Đồng bộ ngay';

  @override
  String get syncing => 'Đang đồng bộ…';

  @override
  String lastSynced(String time) {
    return 'Đồng bộ lần cuối $time';
  }

  @override
  String syncError(String detail) {
    return 'Lỗi đồng bộ: $detail';
  }

  @override
  String get sectionTable => 'Thứ tự bảng số';

  @override
  String get sortDirection => 'Hướng';

  @override
  String get sortDistance => 'Khoảng cách';

  @override
  String get sortTransfers => 'Số lần chuyển';

  @override
  String get metricLabel => 'Cách đo khoảng cách';

  @override
  String get metricWalk => 'Ưu tiên đi bộ';

  @override
  String get metricTotal => 'Tổng khoảng cách';

  @override
  String get sectionLocation => 'Vị trí hiện tại';

  @override
  String get locationOk => 'Có thể lấy';

  @override
  String get locationUnknown => 'Chưa kiểm tra';

  @override
  String get locationDenied => 'Chưa cấp quyền vị trí';

  @override
  String get locationDeniedForever =>
      'Quyền vị trí bị từ chối. Hãy cho phép trong ứng dụng Cài đặt';

  @override
  String get locationServiceDisabled => 'Dịch vụ vị trí đang tắt';

  @override
  String get openSettings => 'Mở Cài đặt';

  @override
  String get retry => 'Thử lại';

  @override
  String get pickerTitle => 'Chọn điểm đến';

  @override
  String get searchHint => 'Tìm địa điểm';

  @override
  String get pickerLongPressHint => 'Nhấn giữ bản đồ để đặt điểm đến';

  @override
  String get searchFailed => 'Không tìm được';

  @override
  String routeMapTitle(String ref) {
    return 'Tuyến $ref';
  }

  @override
  String boardAt(String stop) {
    return 'Lên tại: $stop';
  }

  @override
  String walkMeters(int meters) {
    return 'Đi bộ $meters m';
  }

  @override
  String get busNumberTable => 'Bảng số xe buýt';

  @override
  String currentLocationLabel(String status) {
    return 'Vị trí hiện tại: $status';
  }

  @override
  String get locationAcquired => 'Đã lấy';

  @override
  String get locationFetching => 'Đang lấy…';

  @override
  String get locationNotAcquired => 'Chưa lấy';

  @override
  String get locationNotAllowed =>
      'Chưa được cấp quyền truy cập vị trí. Hãy bật trong Cài đặt.';

  @override
  String get menuMainScreen => 'Nhập số';

  @override
  String get menuTopScreen => 'Ma trận';

  @override
  String get more => 'Khác';

  @override
  String get busNumberHint =>
      'Chỉ nhập số (vd: 35). Hệ thống tự nhận 35A, 35B…';

  @override
  String get ridingLabel => 'Đang đi';

  @override
  String get startRiding => 'Bắt đầu đi';

  @override
  String get getOff => 'Xuống xe';

  @override
  String get distanceLeft => 'Còn';

  @override
  String get tableTapHint =>
      'Chạm để xem bản đồ tuyến, giữ để lên hoặc xuống xe';

  @override
  String get pickOnMap => 'Chọn trên bản đồ';

  @override
  String get chooseVariant => 'Chọn biến thể tuyến';

  @override
  String get busNumberHeader => 'Số xe buýt';

  @override
  String get transfersHeader => 'Số lần chuyển';

  @override
  String get sectionArchive => 'Kho lưu trữ';

  @override
  String archiveCount(int count) {
    return 'Tuyến đã lưu trữ: $count';
  }

  @override
  String get archiveRestore => 'Khôi phục từ kho';

  @override
  String get archiveExport => 'Xuất kho lưu trữ';
}
