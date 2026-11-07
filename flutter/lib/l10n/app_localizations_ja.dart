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
  String get alightNextStop => '1つ先の停留所で降りる';

  @override
  String get alightPreviousStop => '1つ手前の停留所で降りる';

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
  String get keypadSubmit => '判定';

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
  String get moveToCurrentLocation => '現在地に移動';

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

  @override
  String get active => '設定中';

  @override
  String get addPlace => '場所を追加';

  @override
  String get alertAlarm => 'アラーム通知';

  @override
  String get alertFollowSystemVolume => 'システム音量に従う';

  @override
  String get alertNotification => '通知';

  @override
  String get alertNotificationFooter =>
      '降車停に近づいたとき、画面にアラートを出します。アプリが裏にあるときは通知で知らせます。';

  @override
  String get alertSound => 'サウンド';

  @override
  String get alertVibration => 'バイブレーション';

  @override
  String get alertVibrationStrength => 'バイブの強さ';

  @override
  String get arrivalAlerts => '到着アラート';

  @override
  String get cancelNavigation => 'ナビを中止';

  @override
  String get cancelNavigationConfirm => '行き先をやめますか？乗車中の場合は降車扱いになります。';

  @override
  String get cannotBeUndone => 'この操作は取り消せません。';

  @override
  String get choosePlaceAgain => '場所を選び直す';

  @override
  String get chooseSound => 'サウンドを選択';

  @override
  String get clear => 'クリア';

  @override
  String get clearHistory => '履歴を消去';

  @override
  String get clearHistoryConfirm => '履歴をすべて消去しますか？';

  @override
  String get clearHistoryFooter => '目的地の履歴をすべて消去します。';

  @override
  String get currentDestination => '現在の目的地';

  @override
  String get delete => '削除';

  @override
  String get destinationHistory => '目的地の履歴';

  @override
  String distanceAlertBody(int meters) {
    return '${meters}m でアラート';
  }

  @override
  String get distanceAlertMeters => '距離（m）';

  @override
  String distanceAlertN(int n) {
    return '距離アラート $n';
  }

  @override
  String get distanceAlertTitle => '距離アラート';

  @override
  String get distanceAlerts => '距離アラート';

  @override
  String get distanceAlertsFooter =>
      '降車バス停まで設定した距離以内に入ったらアラートします。遠い順にアラームが 1〜3 回鳴ります。';

  @override
  String get done => '完了';

  @override
  String get edit => '編集';

  @override
  String get help => 'ヘルプ';

  @override
  String get hideKeypad => 'テンキーを非表示';

  @override
  String get history => '履歴';

  @override
  String get historyEmpty => '履歴がありません';

  @override
  String get historyEmptyDetail => '目的地を設定すると、ここに履歴として表示されます。';

  @override
  String get historyTapFooter => 'タップすると、その目的地を設定します。';

  @override
  String get keyFeedback => 'キーパッドのフィードバック';

  @override
  String get keyFeedbackClick => 'クリック音';

  @override
  String get keyFeedbackFooter => 'テンキーを押したときの音と振動を調整します。';

  @override
  String get keyFeedbackHaptic => 'バイブレーション';

  @override
  String get keyFeedbackHapticStrength => 'バイブの強さ';

  @override
  String get keypadAppend => '結果表示後も数字を継ぎ足す';

  @override
  String get keypadClearBeforeNew => '結果表示後はクリアして新規入力';

  @override
  String get keypadInput => 'テンキー入力';

  @override
  String get keypadInputFooter => '判定結果が出たあと（⏎ のあと）、テンキーで数字を押したときの動作を選べます。';

  @override
  String get labelHome => '自宅';

  @override
  String get labelSchool => '学校';

  @override
  String get labelWork => '会社';

  @override
  String get language => '言語';

  @override
  String get languageFooter => 'アプリの表示言語を変更できます。';

  @override
  String get languageSystem => '端末の設定に従う';

  @override
  String get lineMap => '路線図';

  @override
  String get longPressToRegister => '長押しで登録';

  @override
  String get longPressToRegisterFooter => '長押しで、現在の目的地をそのまま登録できます。';

  @override
  String get place => '場所';

  @override
  String get placeFooter => '駅名・住所・施設名で検索するか、地図を長押しして選びます。';

  @override
  String get placeName => '名前';

  @override
  String get placeNameFooter => '一覧に表示される名前です。自宅・職場など、わかりやすい名前にしてください。';

  @override
  String get placeNamePlaceholder => '表示名（例: 自宅）';

  @override
  String get preview => 'プレビュー';

  @override
  String get privacyConsent => '同意の管理';

  @override
  String get privacyConsentOff => '同意していません。路線データの取得はしません。';

  @override
  String get privacyConsentOn => '同意しています。';

  @override
  String get privacyDeleteAll => 'すべてのデータを削除';

  @override
  String get privacyDeleteAllConfirm => '保存データを削除しますか？';

  @override
  String get privacyDeleteAllDetail =>
      '目的地、目的地の履歴、登録済みの場所、外部送信への同意と路線データを削除します。一般設定と路線の保管庫は削除されません。';

  @override
  String get privacyFooter => 'データの送信・保存・削除について確認できます。';

  @override
  String get privacyRecipients => '送信先・項目・目的';

  @override
  String get privacyRecipientsBody =>
      '・OpenStreetMap の Overpass API（overpass-api.de、Kumi Systems、Mail.ru）: 現在地の座標と検索半径、路線 ID。路線と停留所の取得のため。同意したときだけ送ります。\n・地図タイル（OpenStreetMap、OSM France）: 表示中の地図の範囲。地図の表示のため。\n・Google マップ（API キーがあり、設定でオンのときだけ）: 表示中の地図の範囲。地図の表示のため。\n・地名検索（Nominatim、Photon）: 入力した地名と、近くを優先するための現在地付近の座標。目的地の検索のため。\n・地名検索（Apple の地図、iOS で検索語句に日本語が含まれるとき）: 入力した地名。日本語の呼び方で場所を探すため。近くを優先するときは現在地付近の座標も送ります。\nバスの判定と番号表は端末の中だけで計算し、Google には何も送りません。';

  @override
  String get privacyStorage => '端末での保存';

  @override
  String get privacyStorageBody =>
      '路線データ、その保管庫、目的地、目的地の履歴、登録済みの場所、直した停留所、設定はこの端末に保存します。iCloud 同期をオンにしたときだけ、路線データ、登録済みの場所、目的地の履歴、直した停留所、番号表・到着アラート・テンキー・言語の設定を自分の iCloud Drive にも保存します。バックアップの書き出しにも同じものが入ります。';

  @override
  String get privacyTitle => 'プライバシーとデータ';

  @override
  String get routeBoardHint => '番号を長押しで乗車・降車';

  @override
  String get routeCandidates => '路線候補';

  @override
  String get routeCandidatesHint => 'バス番号に一致する路線を選んでください。近い順です。';

  @override
  String get routeDataAttribution => '路線データ © OpenStreetMap contributors';

  @override
  String get routeList => '路線一覧';

  @override
  String get routeListEmpty => '路線データがありません';

  @override
  String get routeListEmptyDetail => '設定で路線情報をダウンロードすると、ここに一覧が出ます。';

  @override
  String get routeMapEmpty => 'バス番号を入力して路線を検索';

  @override
  String get routeMapErrorTitle => '路線図エラー';

  @override
  String get routeMapNoLocation => '近い路線から並べるには現在地が必要です。';

  @override
  String routeSearchNone(String number) {
    return '「$number」に一致する路線が端末の路線データにありません。';
  }

  @override
  String get save => '保存';

  @override
  String get savedPlaces => '登録済みの場所';

  @override
  String get savedPlacesEmpty => '登録済みの場所はありません';

  @override
  String get savedPlacesEmptyDetail =>
      '自宅やよく行く場所を登録すると、ワンタップで目的地に設定できます。右上の＋から追加できます。';

  @override
  String get savedPlacesFooter => 'タップで目的地に設定。左スワイプで削除、鉛筆で編集できます。';

  @override
  String get searchFromHistory => '履歴から探す';

  @override
  String get searchFromSavedPlaces => '登録地から探す';

  @override
  String get showKeypad => 'テンキーを表示';

  @override
  String get soundBell => 'ベル';

  @override
  String get soundChime => 'チャイム';

  @override
  String get soundConfirm => '確認音';

  @override
  String get soundDing => 'ディン';

  @override
  String get soundMessage => 'メッセージ';

  @override
  String get soundTiptoes => 'つま先';

  @override
  String get soundTock => 'タック';

  @override
  String get soundTriTone => '三連音';

  @override
  String get strengthHeavy => '強め';

  @override
  String get strengthLight => '弱め';

  @override
  String get strengthMedium => '普通';

  @override
  String get trackingNotice => '到着アラートのため乗車中の位置を追跡しています。';

  @override
  String get volume => '音量';

  @override
  String get wrongDirectionBody => 'このバスは逆方向に走っている可能性があります。乗車前に路線を確認してください。';

  @override
  String get wrongDirectionBodyRouteMap =>
      'このバスは目的地に向かっていない可能性があります。次のバス停で降りてください。';

  @override
  String get wrongDirectionTitle => '逆方向です';

  @override
  String get developerScreen => '開発者画面';

  @override
  String get devAppInfo => 'アプリと端末';

  @override
  String get devLogs => 'ログ';

  @override
  String get devLogsFooter =>
      '不具合を知らせるときは「ログを送る」から、メールなどで送ってください。先頭に端末とアプリの情報が付きます。位置は約100mに丸めて記録しています。';

  @override
  String get devLogSend => 'ログを送る';

  @override
  String devLogSize(int kb, int count) {
    return 'ファイル ${kb}KB・画面 $count件';
  }

  @override
  String get devLogCopy => 'ログをコピー';

  @override
  String get devLogCopied => 'ログをクリップボードにコピーしました。';

  @override
  String get devVerboseLog => '詳細ログ';

  @override
  String get devVerboseLogDetail =>
      '位置の更新や降車停までの距離も記録します。乗車中の不具合を調べるときにオンにしてください。';

  @override
  String get devLogClear => 'ログを消去';

  @override
  String get devLogClearConfirm => 'ログをすべて消去しますか？';

  @override
  String get devTests => 'テスト';

  @override
  String get devTestAlarm => '到着アラームを鳴らす';

  @override
  String get devTestNotification => '5秒後に通知を出す';

  @override
  String get devTestNotificationDetail => '押したあと画面を消すと、裏での通知を確かめられます。';

  @override
  String get devRecentLogs => '最近のログ（新しい順）';

  @override
  String get devNoLogs => 'ログはまだありません';

  @override
  String devTapsLeft(int count) {
    return 'あと $count 回で開発者画面';
  }

  @override
  String get devLogSubject => 'osmBus ログ';

  @override
  String get devLogShareText => 'osmBus のログを送ります。';

  @override
  String devLogSendFailed(String reason) {
    return 'ログを書き出せませんでした: $reason';
  }

  @override
  String versionLabel(String version, String build) {
    return 'バージョン $version ($build)';
  }

  @override
  String get sectionMap => '地図';

  @override
  String get useGoogleMaps => 'Google マップを使う';

  @override
  String get mapsApiKey => 'Google Maps API キー';

  @override
  String mapsKeyUser(String suffix) {
    return '設定済み（…$suffix）';
  }

  @override
  String get mapsKeyBundled => 'アプリに組み込んだキーを使用中';

  @override
  String get mapsKeyNone => '未設定';

  @override
  String get mapsKeyRestart => '変更はアプリの再起動後に反映されます';

  @override
  String get mapsFooter =>
      'API キーがあり、オンのときは Google マップで表示します。それ以外は OpenStreetMap の地図です。路線と停留所はどちらも端末内の OSM データです。';

  @override
  String get mapsFooterAndroid => 'Android ではキーをアプリのビルド時に組み込みます（ここでは変えられません）。';

  @override
  String get mapsKeyDialogMessage =>
      'Maps SDK for iOS を有効にしたキーを入力します。空にして保存すると削除します。';

  @override
  String transferAt(String stop) {
    return '乗換: $stop';
  }

  @override
  String get longPressToBoard => '長押しで乗車';

  @override
  String get longPressToGetOff => '長押しで降車';

  @override
  String get routeReviewOpen => 'この路線を確認';

  @override
  String get stopOrderUsingCustom => '直した順を使っています';

  @override
  String get routeReviewTitle => 'この路線の確認';

  @override
  String get routeReviewOrder => '順番';

  @override
  String get routeReviewEnds => '始点と終点';

  @override
  String routeReviewEndStart(String stop, int meters) {
    return '始点の $stop は、線の端から約 $meters m です。';
  }

  @override
  String routeReviewEndLast(String stop, int meters) {
    return '終点の $stop は、線の端から約 $meters m です。';
  }

  @override
  String get routeReviewEndsProposal => '線の両端に一番近い停留所を、始点と終点にします。';

  @override
  String get routeReviewReset => 'この路線の修正をリセット';

  @override
  String get routeEditsResetAll => '直した停留所をすべてリセット';

  @override
  String get routeEditsResetAllConfirm =>
      'この端末の直した停留所を消し、OSM の並びに戻します。iCloud 同期がオンなら、他の端末の同じ修正も戻します。';

  @override
  String get routeReviewPlace => '場所';

  @override
  String get routeReviewMembership => '停留所の過不足';

  @override
  String get routeReviewNothing => '気になる点はありません';

  @override
  String get routeReviewBacktrackIntro => '今の順では、線の上で 1km 以上戻る停留所があります。';

  @override
  String routeReviewBetween(String stop, String after, String before) {
    return '$stop は、線に沿うと $after と $before のあいだです。';
  }

  @override
  String get routeReviewLineStart => '線の始まり';

  @override
  String get routeReviewLineEnd => '線の終わり';

  @override
  String get routeReviewPartnerDiffers => '復路と、線の向きを考慮しても前後が違います';

  @override
  String get routeReviewProposal =>
      '線から 120m 以内の停留所だけを線に沿った順にし、離れた停留所は今の位置に残します。';

  @override
  String get routeReviewUseThis => 'これを使う';

  @override
  String routeReviewOffLine(String stop, int meters) {
    return '$stop は、この路線の線から約 $meters m 離れています。';
  }

  @override
  String routeReviewReplaceCandidate(String ref, int meters) {
    return '同じ名前の停留所が $ref にあり、この線から約 $meters m です。';
  }

  @override
  String get routeReviewReplace => 'この停留所に差し替える';

  @override
  String get routeReviewFromPartner => '復路にあって、この路線の線の近くにあるが、この路線に入っていない停留所';

  @override
  String get routeReviewFromOthers => '他の路線の停留所で、この線の近くにあるが、この路線に入っていないもの';

  @override
  String get routeReviewOnlyHere => 'この方向にだけある停留所';

  @override
  String routeReviewCandidate(String stop, String ref, int meters) {
    return '$stop（$ref・線から約 $meters m）';
  }

  @override
  String get routeReviewNoAuto => '自動では足しません';

  @override
  String get routeReviewEditSelf => '自分で直す';

  @override
  String get routeReviewRevertOsm => 'OSM の並びに戻す';

  @override
  String get stopOrderUseThis => 'この順で使う';

  @override
  String get stopOrderDragHint => 'ドラッグで順番を入れ替えます。直した内容はこの端末の中だけで使います。';

  @override
  String get stopEditAdd => '停留所を足す';

  @override
  String get stopEditPickOnMap => '地図で場所を指定';

  @override
  String get stopEditPlace => '場所';

  @override
  String get stopEditDelete => '削除';

  @override
  String get stopEditName => '停留所の名前';

  @override
  String get stopEditCoordinates => '緯度・経度';

  @override
  String get stopEditLatitude => '緯度';

  @override
  String get stopEditLongitude => '経度';

  @override
  String get stopEditLongPressHint => '地図を長押ししてピンを置きます。';

  @override
  String get stopEditConfirmPlace => 'この場所にする';

  @override
  String get stopEditNoCandidates => '近くに足せる候補はありません。';

  @override
  String get stopEditAddedByYou => '自分で足した停留所';

  @override
  String get missingNumberEntry => 'この区間に無い番号';

  @override
  String get missingNumberTitle => 'この区間に無い番号';

  @override
  String get missingNumberHint => '乗るはずの番号を入れると、この区間の両端に停留所がある路線を開きます。';

  @override
  String get missingNumberField => 'バス番号';

  @override
  String get missingNumberSearch => '探す';

  @override
  String get missingNumberNone => 'その番号の路線は端末にありません。';

  @override
  String get missingNumberOnSegment => 'この区間の両端に停留所がある路線';

  @override
  String get missingNumberOthers => '番号は一致します。この区間の両端に停留所はありません。';

  @override
  String get settingsGroupAlerts => 'アラートと表示';

  @override
  String get settingsGroupRoutes => '路線データと位置情報';

  @override
  String get settingsGroupBackup => '同期とバックアップ';

  @override
  String get helpIntro => '行き先を決めて、乗れるバスを選ぶアプリです。';

  @override
  String get helpDestTitle => '目的地を決める';

  @override
  String get helpDest1 => '行き先バーをタップ';

  @override
  String get helpDest2 => '地名を検索するか、地図を長押し';

  @override
  String get helpDest3 => '「登録地から探す」「履歴から探す」からも選べる';

  @override
  String get helpOriginTitle => '出発地を変える';

  @override
  String get helpOrigin1 => '現在地バーの地図アイコンをタップ';

  @override
  String get helpOrigin2 => '× で現在地に戻す';

  @override
  String get helpOrigin3 => '↻ で現在地を更新';

  @override
  String get helpPlaceTitle => 'よく行く場所を登録する';

  @override
  String get helpPlace1 => '行き先シートの「登録地から探す」を開く';

  @override
  String get helpPlace2 => '今の目的地は長押しで登録';

  @override
  String get helpRideTitle => '乗車・降車を記録する';

  @override
  String get helpRide1 => 'バス番号を長押しで乗車';

  @override
  String get helpRide2 => '同じ番号をもう一度長押しで降車';

  @override
  String get helpNumberTitle => '番号で乗れるか調べる';

  @override
  String get helpNumber1 => '…の「番号入力」をタップ（左端から右スワイプでも可）';

  @override
  String get helpNumber2 => '数字を入れる';

  @override
  String get helpNumber3 => '乗れるときは「乗車開始」をタップ';

  @override
  String get helpTableTitle => '乗れるバスを見る';

  @override
  String get helpTable1 => '目的地を決めると番号表が出る';

  @override
  String get helpTable2 => '番号をタップで路線図';

  @override
  String get helpTable3 => '乗車中の番号はオレンジ';

  @override
  String get helpDistanceTitle => '距離の色を読む';

  @override
  String get helpDistance1 => '赤・黄・橙の境目は、到着アラートの距離';

  @override
  String get helpDistance2 => '3km未満は緑、3km以上は青';

  @override
  String get helpDistance3 => '乗車中にタップで今のルート図';

  @override
  String get helpLineMapTitle => '路線図を見る';

  @override
  String get helpLineMap1 => '…の「路線図」をタップ';

  @override
  String get helpLineMap2 => 'バス番号で探す';

  @override
  String get helpLineMap3 => '番号バッジの長押しで乗車・降車';

  @override
  String get helpNoRouteTitle => 'ルートが見つからないとき';

  @override
  String get helpNoRoute1 => '設定で路線データをダウンロード';

  @override
  String get helpNoRoute2 => '現在地と目的地が同じ地域か確かめる';

  @override
  String get helpMissingTitle => '乗るはずの番号が表に無いとき';

  @override
  String get helpMissing1 => '「この区間に無い番号」をタップ';

  @override
  String get helpMissing2 => '番号を入れる';

  @override
  String get helpStopTitle => 'ナビをやめたいとき';

  @override
  String get helpStop1 => '距離バッジを長押し';

  @override
  String get helpNetworkTitle => '通信エラーのとき';

  @override
  String get helpNetwork1 => 'Wi‑Fi かモバイルデータを確かめる';

  @override
  String get helpNetwork2 => 'バスの判定は端末内のデータで、オフラインでもできる';

  @override
  String get startupStart => 'はじめる';

  @override
  String get startupDontShowAgain => '次回から表示しない';

  @override
  String get startupSetting => 'スタートアップ画面';

  @override
  String get startupSettingNote => 'アプリ起動時に案内画面を表示します';
}
