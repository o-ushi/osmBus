// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'osmBus';

  @override
  String get settings => '設定';

  @override
  String get reload => '再読み込み';

  @override
  String get cancel => 'キャンセル';

  @override
  String get ok => 'OK';

  @override
  String get never => 'なし';

  @override
  String get destinationUnset => '目的地を設定';

  @override
  String get destinationLabel => '目的地';

  @override
  String get destinationPickedPoint => '地図で選んだ地点';

  @override
  String get tableConsentRequired => 'OSM データの利用に同意すると表示されます';

  @override
  String get noLocation => '現在地がありません';

  @override
  String get tableCalculating => '経路を読み込み中…';

  @override
  String get tableNoRoutes => 'この条件ではルートが見つかりませんでした。現在地・目的地・路線データを確認してください。';

  @override
  String get noRouteData => '路線データがありません';

  @override
  String get headerDirection => '方向';

  @override
  String get headerDirect => '直通';

  @override
  String get headerTransfer1 => '乗換1';

  @override
  String get headerTransfer2 => '乗換2+';

  @override
  String transferCount(String count) {
    return '乗換 $count';
  }

  @override
  String get compassN => '北';

  @override
  String get compassNE => '北東';

  @override
  String get compassE => '東';

  @override
  String get compassSE => '南東';

  @override
  String get compassS => '南';

  @override
  String get compassSW => '南西';

  @override
  String get compassW => '西';

  @override
  String get compassNW => '北西';

  @override
  String get enterBusNumber => 'バス番号を入力';

  @override
  String boardVariant(String names) {
    return '$namesだったら乗ってください！';
  }

  @override
  String get doNotBoard => '見送ってください！';

  @override
  String alightAt(String stop) {
    return '$stop で降車';
  }

  @override
  String estimatedArrival(String time, int minutes) {
    return '到着目安 $time（概算 約$minutes分）';
  }

  @override
  String get directionAny => '向きはどちらでも可。行き先方面なら大丈夫';

  @override
  String directionToward(String direction) {
    return '参考：$direction向き';
  }

  @override
  String get keypadDelete => '消去';

  @override
  String get keypadSubmit => '判定';

  @override
  String ridingNow(String ref) {
    return '乗車中: $ref';
  }

  @override
  String get endRiding => '乗車終了';

  @override
  String get sectionData => '路線データ';

  @override
  String get consentTitle => 'OpenStreetMap データの利用';

  @override
  String get consentDescription => 'Overpass API から周辺のバス路線を取得し、端末に保存します。';

  @override
  String get withdrawConsent => '同意を撤回してデータを削除';

  @override
  String get withdrawConfirm => '保存した路線ファイルを削除します。よろしいですか？';

  @override
  String routeCount(int count) {
    return '路線 $count 件';
  }

  @override
  String geometryCount(int count) {
    return '形状 $count 件';
  }

  @override
  String lastSaved(String time) {
    return '最終保存 $time';
  }

  @override
  String get downloadAll => '全件ダウンロード';

  @override
  String get updateRoutes => '更新';

  @override
  String progress(int done, int total) {
    return '取得中 $done/$total';
  }

  @override
  String downloadFinished(int count) {
    return '形状付き $count 件を保存しました';
  }

  @override
  String updateFinished(int count) {
    return '更新しました（形状付き $count 件）';
  }

  @override
  String get downloadNoRoutes => '周辺に路線がありません';

  @override
  String get downloadConsentRequired => 'OSM データの利用への同意が必要です';

  @override
  String downloadFailed(String detail) {
    return '取得に失敗しました: $detail';
  }

  @override
  String get needsLocation => 'ダウンロードには現在地が必要です';

  @override
  String get sectionBackup => 'バックアップ';

  @override
  String get exportBackup => '書き出し';

  @override
  String get importBackup => '読み込み';

  @override
  String get importChooseMode => '読み込み方法';

  @override
  String get importReplace => '置き換え';

  @override
  String get importMerge => '統合';

  @override
  String importDone(int count) {
    return '$count 件の路線を保存しました';
  }

  @override
  String importFailed(String reason) {
    return '読み込めませんでした: $reason';
  }

  @override
  String get sectionSync => '同期';

  @override
  String get iCloudSync => 'iCloud 同期';

  @override
  String get iCloudOnlyIOS => 'iCloud は iOS のみ';

  @override
  String get iCloudUnavailable => 'iCloud を使えません（未サインイン、またはコンテナが未設定）';

  @override
  String get syncNow => '今すぐ同期';

  @override
  String get syncing => '同期中…';

  @override
  String lastSynced(String time) {
    return '最終同期 $time';
  }

  @override
  String syncError(String detail) {
    return '同期エラー: $detail';
  }

  @override
  String get sectionTable => '番号表の並び';

  @override
  String get sortDirection => '方向';

  @override
  String get sortDistance => '距離';

  @override
  String get sortTransfers => '乗換回数';

  @override
  String get metricLabel => '距離の測り方';

  @override
  String get metricWalk => '徒歩優先';

  @override
  String get metricTotal => '合計距離';

  @override
  String get sectionLocation => '現在地';

  @override
  String get locationOk => '取得できます';

  @override
  String get locationUnknown => '未確認';

  @override
  String get locationDenied => '位置情報が許可されていません';

  @override
  String get locationDeniedForever => '位置情報が拒否されています。設定アプリから許可してください';

  @override
  String get locationServiceDisabled => '位置情報サービスがオフです';

  @override
  String get openSettings => '設定を開く';

  @override
  String get retry => '再試行';

  @override
  String get pickerTitle => '目的地を選ぶ';

  @override
  String get searchHint => '地名を検索';

  @override
  String get pickerLongPressHint => '地図を長押しして目的地を決めます';

  @override
  String get searchFailed => '検索できませんでした';

  @override
  String routeMapTitle(String ref) {
    return '$ref の路線図';
  }

  @override
  String boardAt(String stop) {
    return '乗車: $stop';
  }

  @override
  String walkMeters(int meters) {
    return '徒歩 ${meters}m';
  }

  @override
  String get busNumberTable => 'バス番号表';

  @override
  String currentLocationLabel(String status) {
    return '現在地: $status';
  }

  @override
  String get locationAcquired => '取得済み';

  @override
  String get locationFetching => '取得中…';

  @override
  String get locationNotAcquired => '未取得';

  @override
  String get locationNotAllowed => '位置情報の利用が許可されていません。設定から許可してください。';

  @override
  String get menuMainScreen => '番号入力';

  @override
  String get menuTopScreen => 'マトリクス';

  @override
  String get more => 'その他';

  @override
  String get busNumberHint => '数字だけ入力（例: 35）。35A なども自動で判定します。';

  @override
  String get ridingLabel => '乗車中';

  @override
  String get startRiding => '乗車開始';

  @override
  String get getOff => '降車';

  @override
  String get distanceLeft => 'あと';

  @override
  String get tableTapHint => 'タップで地図、長押しで乗車または降車';

  @override
  String get pickOnMap => '地図から選択';

  @override
  String get chooseVariant => '系統を選択';

  @override
  String get busNumberHeader => 'バス番号';

  @override
  String get transfersHeader => '乗換回数';

  @override
  String get sectionArchive => '保管庫';

  @override
  String archiveCount(int count) {
    return '保管庫の路線: $count 件';
  }

  @override
  String get archiveRestore => '保管庫から復元';

  @override
  String get archiveExport => '保管庫を書き出し';

  @override
  String get pickerTitleOrigin => '出発地を選ぶ';

  @override
  String get pickerLongPressHintOrigin => '地図を長押しして出発地を決めます';

  @override
  String get roleOrigin => '出発地';

  @override
  String get roleDestination => '目的地';

  @override
  String manualOriginLabel(String name) {
    return '出発地: $name';
  }

  @override
  String get clearManualOrigin => '手動出発地をクリア';

  @override
  String get pickOriginOnMap => '出発地を地図から選択';
}
