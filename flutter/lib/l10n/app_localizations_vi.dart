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

  @override
  String get pickerTitleOrigin => 'Chọn điểm đi';

  @override
  String get pickerLongPressHintOrigin => 'Nhấn giữ bản đồ để đặt điểm đi';

  @override
  String get roleOrigin => 'Điểm đi';

  @override
  String get roleDestination => 'Điểm đến';

  @override
  String manualOriginLabel(String name) {
    return 'Điểm đi: $name';
  }

  @override
  String get clearManualOrigin => 'Xóa điểm đi thủ công';

  @override
  String get pickOriginOnMap => 'Chọn điểm đi trên bản đồ';

  @override
  String get active => 'Đang dùng';

  @override
  String get addPlace => 'Thêm địa điểm';

  @override
  String get alertAlarm => 'Chuông cảnh báo';

  @override
  String get alertFollowSystemVolume => 'Theo âm lượng hệ thống';

  @override
  String get alertNotification => 'Thông báo';

  @override
  String get alertNotificationFooter =>
      'Hiện cảnh báo khi gần trạm xuống. Khi ứng dụng chạy nền, sẽ hiện thông báo.';

  @override
  String get alertSound => 'Âm thanh';

  @override
  String get alertVibration => 'Rung';

  @override
  String get alertVibrationStrength => 'Cường độ rung';

  @override
  String get arrivalAlerts => 'Cảnh báo đến nơi';

  @override
  String get cancelNavigation => 'Hủy điều hướng';

  @override
  String get cancelNavigationConfirm =>
      'Hủy chuyến đi này? Nếu đang đi xe, thao tác này coi như xuống xe.';

  @override
  String get cannotBeUndone => 'Không thể hoàn tác thao tác này.';

  @override
  String get choosePlaceAgain => 'Chọn lại địa điểm';

  @override
  String get chooseSound => 'Chọn âm thanh';

  @override
  String get clear => 'Xóa';

  @override
  String get clearHistory => 'Xóa lịch sử';

  @override
  String get clearHistoryConfirm => 'Xóa toàn bộ lịch sử?';

  @override
  String get clearHistoryFooter => 'Xóa toàn bộ lịch sử điểm đến.';

  @override
  String get currentDestination => 'Điểm đến hiện tại';

  @override
  String get delete => 'Xóa';

  @override
  String get destinationHistory => 'Lịch sử điểm đến';

  @override
  String get developerMenu => '🛠 Menu nhà phát triển';

  @override
  String distanceAlertBody(int meters) {
    return 'Cảnh báo ở $meters m';
  }

  @override
  String get distanceAlertMeters => 'Khoảng cách (m)';

  @override
  String distanceAlertN(int n) {
    return 'Cảnh báo khoảng cách $n';
  }

  @override
  String get distanceAlertTitle => 'Cảnh báo khoảng cách';

  @override
  String get distanceAlerts => 'Cảnh báo khoảng cách';

  @override
  String get distanceAlertsFooter =>
      'Cảnh báo khi trong phạm vi khoảng cách đã đặt tới trạm xuống. Chuông reo 1–3 lần, từ mức xa đến mức gần.';

  @override
  String get done => 'Xong';

  @override
  String get edit => 'Sửa';

  @override
  String get help => 'Trợ giúp';

  @override
  String get hideKeypad => 'Ẩn bàn phím số';

  @override
  String get history => 'Lịch sử';

  @override
  String get historyEmpty => 'Chưa có lịch sử';

  @override
  String get historyEmptyDetail => 'Khi bạn đặt điểm đến, nó sẽ hiện ở đây.';

  @override
  String get historyTapFooter => 'Chạm để đặt điểm đến đó.';

  @override
  String get iapLoadFailed => 'Không tải được sản phẩm';

  @override
  String get iapLoading => 'Đang tải sản phẩm…';

  @override
  String get iapPending => 'Giao dịch đang chờ duyệt';

  @override
  String get iapProductMissing => 'Không tìm thấy sản phẩm';

  @override
  String get iapPurchaseFailed => 'Mua không thành công';

  @override
  String get iapReload => 'Tải lại sản phẩm';

  @override
  String get iapRestoreFailed => 'Khôi phục không thành công';

  @override
  String itemCount(int count) {
    return '$count mục';
  }

  @override
  String get keyFeedback => 'Phản hồi bàn phím';

  @override
  String get keyFeedbackClick => 'Âm click';

  @override
  String get keyFeedbackFooter =>
      'Điều chỉnh âm thanh và rung khi bấm bàn phím.';

  @override
  String get keyFeedbackHaptic => 'Rung';

  @override
  String get keyFeedbackHapticStrength => 'Cường độ rung';

  @override
  String get keypadAppend => 'Nối thêm số sau khi có kết quả';

  @override
  String get keypadClearBeforeNew => 'Xóa và nhập mới sau khi có kết quả';

  @override
  String get keypadInput => 'Nhập trên bàn phím số';

  @override
  String get keypadInputFooter =>
      'Chọn cách nhập số sau khi đã hiển thị kết quả kiểm tra (sau ⏎).';

  @override
  String get labelHome => 'Nhà';

  @override
  String get labelSchool => 'Trường';

  @override
  String get labelWork => 'Công ty';

  @override
  String get language => 'Ngôn ngữ';

  @override
  String get languageFooter => 'Bạn có thể đổi ngôn ngữ hiển thị của ứng dụng.';

  @override
  String get languageSystem => 'Theo ngôn ngữ thiết bị';

  @override
  String get lineMap => 'Sơ đồ tuyến';

  @override
  String get longPressToRegister => 'Giữ để lưu';

  @override
  String get longPressToRegisterFooter => 'Giữ để lưu ngay điểm đến hiện tại.';

  @override
  String get place => 'Địa điểm';

  @override
  String get placeFooter =>
      'Tìm theo tên trạm, địa chỉ hoặc địa điểm, hoặc giữ trên bản đồ.';

  @override
  String get placeName => 'Tên';

  @override
  String get placeNameFooter =>
      'Tên hiển thị trong danh sách. Hãy dùng tên dễ nhận biết như Nhà hoặc Công ty.';

  @override
  String get placeNamePlaceholder => 'Tên hiển thị (vd: Nhà)';

  @override
  String get planCurrent => 'Gói hiện tại';

  @override
  String get planFree => 'FREE';

  @override
  String get planFreeDescription =>
      'Bạn đang dùng gói FREE. Nâng cấp lên PREMIUM để lưu không giới hạn địa điểm và lịch sử.';

  @override
  String planFreeLimitFooter(int count) {
    return 'Với gói FREE, bạn lưu được tối đa $count mục lịch sử và $count địa điểm. Nâng cấp lên PREMIUM để lưu không giới hạn.';
  }

  @override
  String get planManagement => 'Quản lý gói';

  @override
  String get planNothingToRestore => 'Không tìm thấy giao dịch để khôi phục.';

  @override
  String get planPremium => 'PREMIUM';

  @override
  String get planPremiumLimitFooter =>
      'Với gói PREMIUM, lịch sử và địa điểm đã lưu không giới hạn.';

  @override
  String get planRestore => 'Khôi phục giao dịch';

  @override
  String get planRestoreFooter =>
      'Nếu bạn đã mua PREMIUM trên cửa hàng, hãy khôi phục tại đây.';

  @override
  String get planRestored => 'Đã khôi phục giao dịch.';

  @override
  String get planSwitchDescription =>
      'Chỉ có trong bản debug. Không ảnh hưởng giao dịch trên cửa hàng.';

  @override
  String get planUpgrade => 'Nâng cấp lên PREMIUM';

  @override
  String get planUpgradeDone => 'Đã nâng cấp lên PREMIUM!';

  @override
  String get preview => 'Nghe thử';

  @override
  String get privacyConsent => 'Quản lý đồng ý';

  @override
  String get privacyConsentOff => 'Chưa đồng ý. Không tải dữ liệu tuyến.';

  @override
  String get privacyConsentOn => 'Đã đồng ý.';

  @override
  String get privacyDeleteAll => 'Xóa toàn bộ dữ liệu';

  @override
  String get privacyDeleteAllConfirm => 'Xóa dữ liệu đã lưu?';

  @override
  String get privacyDeleteAllDetail =>
      'Xóa điểm đến, lịch sử điểm đến, địa điểm đã lưu, sự đồng ý gửi dữ liệu ra ngoài và dữ liệu tuyến. Trạng thái mua, cài đặt chung và kho lưu trữ tuyến không bị xóa.';

  @override
  String get privacyFooter => 'Xem cách dữ liệu được gửi, lưu và xóa.';

  @override
  String get privacyRecipients => 'Nơi nhận, dữ liệu và mục đích';

  @override
  String get privacyRecipientsBody =>
      '• OpenStreetMap Overpass API (overpass-api.de, Kumi Systems, Mail.ru): vị trí, bán kính tìm và mã tuyến, để tải tuyến và trạm. Chỉ gửi khi bạn đồng ý.\n• Ô bản đồ (OpenStreetMap, OSM France): vùng bản đồ đang xem, để hiển thị bản đồ.\n• Google Maps (chỉ khi có khóa API và bật trong cài đặt): vùng bản đồ đang xem, để hiển thị bản đồ.\n• Tìm địa điểm (Nominatim, Photon): nội dung tìm kiếm và tọa độ gần đó để xếp kết quả.\n• App Store / Google Play: mua và khôi phục PREMIUM.\nKiểm tra xe buýt và bảng số xe chỉ được tính trên thiết bị. Không gửi gì cho Google.';

  @override
  String get privacyStorage => 'Lưu trên thiết bị';

  @override
  String get privacyStorageBody =>
      'Dữ liệu tuyến, kho lưu trữ, điểm đến, lịch sử điểm đến, địa điểm đã lưu và cài đặt được lưu trên thiết bị này. Dữ liệu tuyến chỉ được lưu vào iCloud Drive của bạn khi bật đồng bộ iCloud.';

  @override
  String get privacyTitle => 'Quyền riêng tư & dữ liệu';

  @override
  String get routeBoardHint => 'Giữ số xe để lên hoặc xuống';

  @override
  String get routeCandidates => 'Tuyến phù hợp';

  @override
  String get routeCandidatesHint =>
      'Chọn tuyến khớp với số xe. Gần nhất trước.';

  @override
  String get routeDataAttribution =>
      'Dữ liệu tuyến © OpenStreetMap contributors';

  @override
  String get routeList => 'Danh sách tuyến';

  @override
  String get routeListEmpty => 'Chưa có dữ liệu tuyến';

  @override
  String get routeListEmptyDetail =>
      'Tải dữ liệu tuyến trong Cài đặt để hiện danh sách ở đây.';

  @override
  String get routeMapEmpty => 'Nhập số xe để tìm tuyến';

  @override
  String get routeMapErrorTitle => 'Lỗi sơ đồ tuyến';

  @override
  String get routeMapNoLocation =>
      'Cần vị trí hiện tại để xếp tuyến gần trước.';

  @override
  String routeSearchNone(String number) {
    return 'Không có tuyến khớp \"$number\" trong dữ liệu tuyến trên thiết bị.';
  }

  @override
  String get save => 'Lưu';

  @override
  String get savedPlaces => 'Địa điểm đã lưu';

  @override
  String get savedPlacesEmpty => 'Chưa có địa điểm đã lưu';

  @override
  String get savedPlacesEmptyDetail =>
      'Lưu nhà hoặc nơi thường đến để đặt điểm đến chỉ với một chạm. Thêm bằng nút + ở góc trên bên phải.';

  @override
  String get savedPlacesFooter =>
      'Chạm để đặt làm điểm đến. Vuốt trái để xóa, chạm bút chì để sửa.';

  @override
  String savedPlacesFreeLimit(int count) {
    return 'Gói FREE chỉ cho phép $count địa điểm đã lưu.';
  }

  @override
  String get searchFromHistory => 'Lịch sử';

  @override
  String get searchFromSavedPlaces => 'Địa điểm đã lưu';

  @override
  String get showKeypad => 'Hiện bàn phím số';

  @override
  String get soundBell => 'Chuông cửa';

  @override
  String get soundChime => 'Chuông';

  @override
  String get soundConfirm => 'Âm xác nhận';

  @override
  String get soundDing => 'Ding';

  @override
  String get soundMessage => 'Tin nhắn';

  @override
  String get soundTiptoes => 'Tiptoes';

  @override
  String get soundTock => 'Tách';

  @override
  String get soundTriTone => 'Ba âm';

  @override
  String get strengthHeavy => 'Mạnh';

  @override
  String get strengthLight => 'Nhẹ';

  @override
  String get strengthMedium => 'Vừa';

  @override
  String get trackingNotice => 'Đang theo dõi chuyến đi để cảnh báo đến nơi.';

  @override
  String get unlimited => 'Không giới hạn';

  @override
  String get volume => 'Âm lượng';

  @override
  String get wrongDirectionBody =>
      'Xe buýt có thể đi ngược hướng. Hãy kiểm tra tuyến trước khi lên xe.';

  @override
  String get wrongDirectionBodyRouteMap =>
      'Xe này có thể không đi về hướng điểm đến. Hãy xuống ở trạm kế tiếp.';

  @override
  String get wrongDirectionTitle => 'Ngược hướng?';

  @override
  String get helpIntro =>
      'Ứng dụng mở ở màn hình Ma trận. Đặt điểm đến và chọn xe từ bảng số xe. Bàn phím số ở … → Nhập số, hoặc vuốt sang phải từ mép trái.';

  @override
  String get helpBasics => 'Thao tác cơ bản';

  @override
  String get helpResults => 'Cách đọc kết quả';

  @override
  String get helpRoutes => 'Xem tuyến';

  @override
  String get helpTroubleshooting => 'Khắc phục sự cố';

  @override
  String get helpTopTitle => 'Ma trận';

  @override
  String get helpTopBody =>
      'Đây là màn hình khi mở ứng dụng: điểm đến, vị trí, khoảng cách và bảng số xe. Để kiểm tra số trên bàn phím, mở … → Nhập số. Cũng có thể vuốt sang phải từ mép trái. Quay lại bằng … → Ma trận, hoặc vuốt từ mép trái lần nữa.';

  @override
  String get helpDestinationTitle => 'Đặt điểm đến';

  @override
  String get helpDestinationBody =>
      'Chạm thanh điểm đến để mở bản đồ. Tìm theo tên hoặc giữ trên bản đồ, hoặc chọn từ Lịch sử hay Địa điểm đã lưu. Chuyển giữa điểm đi và điểm đến ở đầu bảng.';

  @override
  String get helpLocationTitle => 'Vị trí và điểm đi';

  @override
  String get helpLocationBody =>
      'Ứng dụng xin quyền vị trí khi mở. Làm mới bằng ↻ trên thanh vị trí, hoặc chọn điểm đi trên bản đồ bằng biểu tượng bản đồ. Chạm × để quay lại vị trí hiện tại. Khi đang đi, khoảng cách luôn đo từ GPS.';

  @override
  String get helpSavedPlacesTitle => 'Địa điểm đã lưu';

  @override
  String get helpSavedPlacesBody =>
      'Mở Địa điểm đã lưu trong bảng điểm đến để lưu nhà và nơi thường đến. Chạm để đặt làm điểm đến. Giữ điểm đến hiện tại để lưu ngay.';

  @override
  String get helpBusNumberTitle => 'Nhập số xe buýt';

  @override
  String get helpBusNumberBody =>
      'Chỉ khi số không có trên bảng, mở … → Nhập số (hoặc vuốt từ mép trái) rồi chỉ nhập số (vd: 35). Ứng dụng đối chiếu tuyến; nếu xe tới điểm trung chuyển thì vẫn có thể lên xe.';

  @override
  String get helpTableTitle => 'Bảng số xe buýt';

  @override
  String get helpTableBody =>
      'Số xe được nhóm theo hướng và số lần chuyển. Chạm để mở bản đồ tuyến, giữ để lên hoặc xuống xe. Xe đang đi có màu cam.';

  @override
  String get helpBoardTitle => 'Bắt đầu đi';

  @override
  String get helpBoardBody =>
      'Trên Nhập số, số xe bạn nhập được đối chiếu với tuyến đến điểm đến. Nếu có biến thể phù hợp, thông báo vàng như \"Nếu là 35A thì lên xe!\" sẽ hiện; chạm Bắt đầu đi.';

  @override
  String get helpSkipTitle => 'Bỏ qua xe này!';

  @override
  String get helpSkipBody =>
      'Khi không có biến thể phù hợp đi tới điểm đến, màn hình hiển thị đỏ \"Bỏ qua xe này!\".';

  @override
  String get helpDistanceTitle => 'Màu khoảng cách';

  @override
  String get helpDistanceBody =>
      'Khi chưa lên xe, huy hiệu là khoảng cách thẳng đến điểm đến. Khi đang đi, là khoảng cách đến trạm xuống của xe hiện tại. Từ 3 km xanh dương, từ 1 km xanh lá, từ 500 m vàng, từ 200 m cam, dưới 200 m đỏ. Khi đang đi, chạm huy hiệu để mở bản đồ tuyến. Giữ huy hiệu để hủy điều hướng (cũng xóa điểm đến). Nếu lên xe từ sơ đồ tuyến mà chưa đặt điểm đến, huy hiệu hiện \"—\".';

  @override
  String get helpRidingTitle => 'Chế độ đang đi';

  @override
  String get helpRidingBody =>
      'Giữ số xe để bắt đầu đi. Giữ lần nữa để xuống (chuyển tuyến). Khi đang đi, cảnh báo đến nơi reo theo khoảng cách tới trạm xuống và vẫn theo dõi khi tắt màn hình. Ứng dụng cảnh báo nếu xe có vẻ đi ngược hướng.';

  @override
  String get helpLineMapTitle => 'Sơ đồ tuyến';

  @override
  String get helpLineMapBody =>
      '… → Sơ đồ tuyến tìm tuyến theo số xe trong dữ liệu trên thiết bị và vẽ lên bản đồ. Dùng nút danh sách để xem các tuyến đã lưu. Giữ huy hiệu số để lên hoặc xuống (trạm cuối là trạm xuống).';

  @override
  String get helpSettingsTitle => 'Cài đặt & cảnh báo';

  @override
  String get helpSettingsBody =>
      'Từ … → Cài đặt bạn có thể đổi ngôn ngữ, cách nhập bàn phím, âm thanh và rung, cảnh báo đến nơi và dữ liệu tuyến. Cảnh báo đến nơi dựa trên khoảng cách đến trạm xuống, tối đa 3 mức — chuông reo 1–3 lần từ xa đến gần. Khi ứng dụng chạy nền, sẽ hiện thông báo.';

  @override
  String get helpPlanTitle => 'Quản lý gói';

  @override
  String helpPlanBody(int count) {
    return 'Mở … → Quản lý gói để xem gói hiện tại, nâng cấp lên PREMIUM hoặc khôi phục giao dịch. Gói FREE: tối đa $count địa điểm đã lưu và $count mục lịch sử. PREMIUM: không giới hạn.';
  }

  @override
  String get helpNoRouteTitle => 'Không tìm thấy tuyến';

  @override
  String get helpNoRouteBody =>
      'Hãy chắc rằng bạn đã tải dữ liệu tuyến trong Cài đặt, và vị trí với điểm đến cùng khu vực. Dữ liệu tuyến được tải quanh vị trí hiện tại.';

  @override
  String get helpNetworkTitle => 'Lỗi kết nối';

  @override
  String get helpNetworkBody =>
      'Kiểm tra Wi‑Fi hoặc dữ liệu di động rồi thử lại. Kiểm tra xe dùng dữ liệu tuyến trên thiết bị nên vẫn dùng được khi ngoại tuyến.';

  @override
  String get developerScreen => 'Nhà phát triển';

  @override
  String get devAppInfo => 'Ứng dụng và thiết bị';

  @override
  String get devLogs => 'Nhật ký';

  @override
  String get devLogsFooter =>
      'Để báo lỗi, chọn Gửi nhật ký và gửi qua email hoặc ứng dụng khác. Thông tin thiết bị và ứng dụng được thêm ở đầu. Vị trí được làm tròn khoảng 100 m.';

  @override
  String get devLogSend => 'Gửi nhật ký';

  @override
  String devLogSize(int kb, int count) {
    return 'Tệp $kb KB · $count trên màn hình';
  }

  @override
  String get devLogCopy => 'Sao chép nhật ký';

  @override
  String get devLogCopied => 'Đã sao chép nhật ký.';

  @override
  String get devVerboseLog => 'Nhật ký chi tiết';

  @override
  String get devVerboseLogDetail =>
      'Ghi cả cập nhật vị trí và khoảng cách đến trạm. Bật khi kiểm tra lỗi trong chuyến đi.';

  @override
  String get devLogClear => 'Xóa nhật ký';

  @override
  String get devLogClearConfirm => 'Xóa toàn bộ nhật ký?';

  @override
  String get devTests => 'Kiểm tra';

  @override
  String get devTestAlarm => 'Phát chuông đến nơi';

  @override
  String get devTestNotification => 'Hiện thông báo sau 5 giây';

  @override
  String get devTestNotificationDetail =>
      'Khóa màn hình sau khi chạm để kiểm tra thông báo nền.';

  @override
  String get devRecentLogs => 'Nhật ký gần đây (mới nhất trước)';

  @override
  String get devNoLogs => 'Chưa có nhật ký';

  @override
  String devTapsLeft(int count) {
    return 'Còn $count lần chạm để mở màn hình nhà phát triển';
  }

  @override
  String get devLogSubject => 'Nhật ký osmBus';

  @override
  String get devLogShareText => 'Gửi nhật ký osmBus.';

  @override
  String devLogSendFailed(String reason) {
    return 'Không xuất được nhật ký: $reason';
  }

  @override
  String versionLabel(String version, String build) {
    return 'Phiên bản $version ($build)';
  }

  @override
  String get sectionMap => 'Bản đồ';

  @override
  String get useGoogleMaps => 'Dùng Google Maps';

  @override
  String get mapsApiKey => 'Khóa API Google Maps';

  @override
  String mapsKeyUser(String suffix) {
    return 'Đã đặt (…$suffix)';
  }

  @override
  String get mapsKeyBundled => 'Đang dùng khóa tích hợp trong ứng dụng';

  @override
  String get mapsKeyNone => 'Chưa đặt';

  @override
  String get mapsKeyRestart => 'Khởi động lại ứng dụng để áp dụng thay đổi';

  @override
  String get mapsFooter =>
      'Khi có khóa API và bật mục này, bản đồ hiển thị bằng Google Maps. Nếu không, dùng bản đồ OpenStreetMap. Tuyến và trạm luôn lấy từ dữ liệu OSM trên thiết bị.';

  @override
  String get mapsFooterAndroid =>
      'Trên Android, khóa được tích hợp khi build ứng dụng và không đổi được ở đây.';

  @override
  String get mapsKeyDialogMessage =>
      'Nhập khóa đã bật Maps SDK for iOS. Lưu trống để xóa khóa.';

  @override
  String transferAt(String stop) {
    return 'Chuyển tuyến: $stop';
  }

  @override
  String get longPressToBoard => 'Nhấn giữ để lên xe';

  @override
  String get longPressToGetOff => 'Nhấn giữ để xuống xe';
}
