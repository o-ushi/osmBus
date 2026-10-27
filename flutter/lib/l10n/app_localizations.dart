import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale('vi'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In ja, this message translates to:
  /// **'osmBus'**
  String get appTitle;

  /// No description provided for @settings.
  ///
  /// In ja, this message translates to:
  /// **'設定'**
  String get settings;

  /// No description provided for @reload.
  ///
  /// In ja, this message translates to:
  /// **'再読み込み'**
  String get reload;

  /// No description provided for @cancel.
  ///
  /// In ja, this message translates to:
  /// **'キャンセル'**
  String get cancel;

  /// No description provided for @ok.
  ///
  /// In ja, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @never.
  ///
  /// In ja, this message translates to:
  /// **'なし'**
  String get never;

  /// No description provided for @destinationUnset.
  ///
  /// In ja, this message translates to:
  /// **'目的地を設定'**
  String get destinationUnset;

  /// No description provided for @destinationLabel.
  ///
  /// In ja, this message translates to:
  /// **'目的地'**
  String get destinationLabel;

  /// No description provided for @destinationPickedPoint.
  ///
  /// In ja, this message translates to:
  /// **'地図で選んだ地点'**
  String get destinationPickedPoint;

  /// No description provided for @tableConsentRequired.
  ///
  /// In ja, this message translates to:
  /// **'OSM データの利用に同意すると表示されます'**
  String get tableConsentRequired;

  /// No description provided for @noLocation.
  ///
  /// In ja, this message translates to:
  /// **'現在地がありません'**
  String get noLocation;

  /// No description provided for @tableCalculating.
  ///
  /// In ja, this message translates to:
  /// **'経路を読み込み中…'**
  String get tableCalculating;

  /// No description provided for @tableNoRoutes.
  ///
  /// In ja, this message translates to:
  /// **'この条件ではルートが見つかりませんでした。現在地・目的地・路線データを確認してください。'**
  String get tableNoRoutes;

  /// No description provided for @noRouteData.
  ///
  /// In ja, this message translates to:
  /// **'路線データがありません'**
  String get noRouteData;

  /// No description provided for @headerDirection.
  ///
  /// In ja, this message translates to:
  /// **'方向'**
  String get headerDirection;

  /// No description provided for @headerDirect.
  ///
  /// In ja, this message translates to:
  /// **'直通'**
  String get headerDirect;

  /// No description provided for @headerTransfer1.
  ///
  /// In ja, this message translates to:
  /// **'乗換1'**
  String get headerTransfer1;

  /// No description provided for @headerTransfer2.
  ///
  /// In ja, this message translates to:
  /// **'乗換2+'**
  String get headerTransfer2;

  /// No description provided for @transferCount.
  ///
  /// In ja, this message translates to:
  /// **'乗換 {count}'**
  String transferCount(String count);

  /// No description provided for @compassN.
  ///
  /// In ja, this message translates to:
  /// **'北'**
  String get compassN;

  /// No description provided for @compassNE.
  ///
  /// In ja, this message translates to:
  /// **'北東'**
  String get compassNE;

  /// No description provided for @compassE.
  ///
  /// In ja, this message translates to:
  /// **'東'**
  String get compassE;

  /// No description provided for @compassSE.
  ///
  /// In ja, this message translates to:
  /// **'南東'**
  String get compassSE;

  /// No description provided for @compassS.
  ///
  /// In ja, this message translates to:
  /// **'南'**
  String get compassS;

  /// No description provided for @compassSW.
  ///
  /// In ja, this message translates to:
  /// **'南西'**
  String get compassSW;

  /// No description provided for @compassW.
  ///
  /// In ja, this message translates to:
  /// **'西'**
  String get compassW;

  /// No description provided for @compassNW.
  ///
  /// In ja, this message translates to:
  /// **'北西'**
  String get compassNW;

  /// No description provided for @enterBusNumber.
  ///
  /// In ja, this message translates to:
  /// **'バス番号を入力'**
  String get enterBusNumber;

  /// No description provided for @boardVariant.
  ///
  /// In ja, this message translates to:
  /// **'{names}だったら乗ってください！'**
  String boardVariant(String names);

  /// No description provided for @doNotBoard.
  ///
  /// In ja, this message translates to:
  /// **'見送ってください！'**
  String get doNotBoard;

  /// No description provided for @alightAt.
  ///
  /// In ja, this message translates to:
  /// **'{stop} で降車'**
  String alightAt(String stop);

  /// No description provided for @estimatedArrival.
  ///
  /// In ja, this message translates to:
  /// **'到着目安 {time}（概算 約{minutes}分）'**
  String estimatedArrival(String time, int minutes);

  /// No description provided for @directionAny.
  ///
  /// In ja, this message translates to:
  /// **'向きはどちらでも可。行き先方面なら大丈夫'**
  String get directionAny;

  /// No description provided for @directionToward.
  ///
  /// In ja, this message translates to:
  /// **'参考：{direction}向き'**
  String directionToward(String direction);

  /// No description provided for @keypadDelete.
  ///
  /// In ja, this message translates to:
  /// **'消去'**
  String get keypadDelete;

  /// No description provided for @keypadSubmit.
  ///
  /// In ja, this message translates to:
  /// **'判定'**
  String get keypadSubmit;

  /// No description provided for @ridingNow.
  ///
  /// In ja, this message translates to:
  /// **'乗車中: {ref}'**
  String ridingNow(String ref);

  /// No description provided for @endRiding.
  ///
  /// In ja, this message translates to:
  /// **'乗車終了'**
  String get endRiding;

  /// No description provided for @sectionData.
  ///
  /// In ja, this message translates to:
  /// **'路線データ'**
  String get sectionData;

  /// No description provided for @consentTitle.
  ///
  /// In ja, this message translates to:
  /// **'OpenStreetMap データの利用'**
  String get consentTitle;

  /// No description provided for @consentDescription.
  ///
  /// In ja, this message translates to:
  /// **'Overpass API から周辺のバス路線を取得し、端末に保存します。'**
  String get consentDescription;

  /// No description provided for @withdrawConsent.
  ///
  /// In ja, this message translates to:
  /// **'同意を撤回してデータを削除'**
  String get withdrawConsent;

  /// No description provided for @withdrawConfirm.
  ///
  /// In ja, this message translates to:
  /// **'保存した路線ファイルを削除します。よろしいですか？'**
  String get withdrawConfirm;

  /// No description provided for @routeCount.
  ///
  /// In ja, this message translates to:
  /// **'路線 {count} 件'**
  String routeCount(int count);

  /// No description provided for @geometryCount.
  ///
  /// In ja, this message translates to:
  /// **'形状 {count} 件'**
  String geometryCount(int count);

  /// No description provided for @lastSaved.
  ///
  /// In ja, this message translates to:
  /// **'最終保存 {time}'**
  String lastSaved(String time);

  /// No description provided for @downloadAll.
  ///
  /// In ja, this message translates to:
  /// **'全件ダウンロード'**
  String get downloadAll;

  /// No description provided for @updateRoutes.
  ///
  /// In ja, this message translates to:
  /// **'更新'**
  String get updateRoutes;

  /// No description provided for @progress.
  ///
  /// In ja, this message translates to:
  /// **'取得中 {done}/{total}'**
  String progress(int done, int total);

  /// No description provided for @downloadFinished.
  ///
  /// In ja, this message translates to:
  /// **'形状付き {count} 件を保存しました'**
  String downloadFinished(int count);

  /// No description provided for @updateFinished.
  ///
  /// In ja, this message translates to:
  /// **'更新しました（形状付き {count} 件）'**
  String updateFinished(int count);

  /// No description provided for @downloadNoRoutes.
  ///
  /// In ja, this message translates to:
  /// **'周辺に路線がありません'**
  String get downloadNoRoutes;

  /// No description provided for @downloadConsentRequired.
  ///
  /// In ja, this message translates to:
  /// **'OSM データの利用への同意が必要です'**
  String get downloadConsentRequired;

  /// No description provided for @downloadFailed.
  ///
  /// In ja, this message translates to:
  /// **'取得に失敗しました: {detail}'**
  String downloadFailed(String detail);

  /// No description provided for @needsLocation.
  ///
  /// In ja, this message translates to:
  /// **'ダウンロードには現在地が必要です'**
  String get needsLocation;

  /// No description provided for @sectionBackup.
  ///
  /// In ja, this message translates to:
  /// **'バックアップ'**
  String get sectionBackup;

  /// No description provided for @exportBackup.
  ///
  /// In ja, this message translates to:
  /// **'書き出し'**
  String get exportBackup;

  /// No description provided for @importBackup.
  ///
  /// In ja, this message translates to:
  /// **'読み込み'**
  String get importBackup;

  /// No description provided for @importChooseMode.
  ///
  /// In ja, this message translates to:
  /// **'読み込み方法'**
  String get importChooseMode;

  /// No description provided for @importReplace.
  ///
  /// In ja, this message translates to:
  /// **'置き換え'**
  String get importReplace;

  /// No description provided for @importMerge.
  ///
  /// In ja, this message translates to:
  /// **'統合'**
  String get importMerge;

  /// No description provided for @importDone.
  ///
  /// In ja, this message translates to:
  /// **'{count} 件の路線を保存しました'**
  String importDone(int count);

  /// No description provided for @importFailed.
  ///
  /// In ja, this message translates to:
  /// **'読み込めませんでした: {reason}'**
  String importFailed(String reason);

  /// No description provided for @sectionSync.
  ///
  /// In ja, this message translates to:
  /// **'同期'**
  String get sectionSync;

  /// No description provided for @iCloudSync.
  ///
  /// In ja, this message translates to:
  /// **'iCloud 同期'**
  String get iCloudSync;

  /// No description provided for @iCloudOnlyIOS.
  ///
  /// In ja, this message translates to:
  /// **'iCloud は iOS のみ'**
  String get iCloudOnlyIOS;

  /// No description provided for @iCloudUnavailable.
  ///
  /// In ja, this message translates to:
  /// **'iCloud を使えません（未サインイン、またはコンテナが未設定）'**
  String get iCloudUnavailable;

  /// No description provided for @syncNow.
  ///
  /// In ja, this message translates to:
  /// **'今すぐ同期'**
  String get syncNow;

  /// No description provided for @syncing.
  ///
  /// In ja, this message translates to:
  /// **'同期中…'**
  String get syncing;

  /// No description provided for @lastSynced.
  ///
  /// In ja, this message translates to:
  /// **'最終同期 {time}'**
  String lastSynced(String time);

  /// No description provided for @syncError.
  ///
  /// In ja, this message translates to:
  /// **'同期エラー: {detail}'**
  String syncError(String detail);

  /// No description provided for @sectionTable.
  ///
  /// In ja, this message translates to:
  /// **'番号表の並び'**
  String get sectionTable;

  /// No description provided for @sortDirection.
  ///
  /// In ja, this message translates to:
  /// **'方向'**
  String get sortDirection;

  /// No description provided for @sortDistance.
  ///
  /// In ja, this message translates to:
  /// **'距離'**
  String get sortDistance;

  /// No description provided for @sortTransfers.
  ///
  /// In ja, this message translates to:
  /// **'乗換回数'**
  String get sortTransfers;

  /// No description provided for @metricLabel.
  ///
  /// In ja, this message translates to:
  /// **'距離の測り方'**
  String get metricLabel;

  /// No description provided for @metricWalk.
  ///
  /// In ja, this message translates to:
  /// **'徒歩優先'**
  String get metricWalk;

  /// No description provided for @metricTotal.
  ///
  /// In ja, this message translates to:
  /// **'合計距離'**
  String get metricTotal;

  /// No description provided for @sectionLocation.
  ///
  /// In ja, this message translates to:
  /// **'現在地'**
  String get sectionLocation;

  /// No description provided for @locationOk.
  ///
  /// In ja, this message translates to:
  /// **'取得できます'**
  String get locationOk;

  /// No description provided for @locationUnknown.
  ///
  /// In ja, this message translates to:
  /// **'未確認'**
  String get locationUnknown;

  /// No description provided for @locationDenied.
  ///
  /// In ja, this message translates to:
  /// **'位置情報が許可されていません'**
  String get locationDenied;

  /// No description provided for @locationDeniedForever.
  ///
  /// In ja, this message translates to:
  /// **'位置情報が拒否されています。設定アプリから許可してください'**
  String get locationDeniedForever;

  /// No description provided for @locationServiceDisabled.
  ///
  /// In ja, this message translates to:
  /// **'位置情報サービスがオフです'**
  String get locationServiceDisabled;

  /// No description provided for @openSettings.
  ///
  /// In ja, this message translates to:
  /// **'設定を開く'**
  String get openSettings;

  /// No description provided for @retry.
  ///
  /// In ja, this message translates to:
  /// **'再試行'**
  String get retry;

  /// No description provided for @pickerTitle.
  ///
  /// In ja, this message translates to:
  /// **'目的地を選ぶ'**
  String get pickerTitle;

  /// No description provided for @searchHint.
  ///
  /// In ja, this message translates to:
  /// **'地名を検索'**
  String get searchHint;

  /// No description provided for @pickerLongPressHint.
  ///
  /// In ja, this message translates to:
  /// **'地図を長押しして目的地を決めます'**
  String get pickerLongPressHint;

  /// No description provided for @searchFailed.
  ///
  /// In ja, this message translates to:
  /// **'検索できませんでした'**
  String get searchFailed;

  /// No description provided for @routeMapTitle.
  ///
  /// In ja, this message translates to:
  /// **'{ref} の路線図'**
  String routeMapTitle(String ref);

  /// No description provided for @boardAt.
  ///
  /// In ja, this message translates to:
  /// **'乗車: {stop}'**
  String boardAt(String stop);

  /// No description provided for @walkMeters.
  ///
  /// In ja, this message translates to:
  /// **'徒歩 {meters}m'**
  String walkMeters(int meters);

  /// No description provided for @busNumberTable.
  ///
  /// In ja, this message translates to:
  /// **'バス番号表'**
  String get busNumberTable;

  /// No description provided for @currentLocationLabel.
  ///
  /// In ja, this message translates to:
  /// **'現在地: {status}'**
  String currentLocationLabel(String status);

  /// No description provided for @locationAcquired.
  ///
  /// In ja, this message translates to:
  /// **'取得済み'**
  String get locationAcquired;

  /// No description provided for @locationFetching.
  ///
  /// In ja, this message translates to:
  /// **'取得中…'**
  String get locationFetching;

  /// No description provided for @locationNotAcquired.
  ///
  /// In ja, this message translates to:
  /// **'未取得'**
  String get locationNotAcquired;

  /// No description provided for @locationNotAllowed.
  ///
  /// In ja, this message translates to:
  /// **'位置情報の利用が許可されていません。設定から許可してください。'**
  String get locationNotAllowed;

  /// No description provided for @menuMainScreen.
  ///
  /// In ja, this message translates to:
  /// **'番号入力'**
  String get menuMainScreen;

  /// No description provided for @menuTopScreen.
  ///
  /// In ja, this message translates to:
  /// **'マトリクス'**
  String get menuTopScreen;

  /// No description provided for @more.
  ///
  /// In ja, this message translates to:
  /// **'その他'**
  String get more;

  /// No description provided for @busNumberHint.
  ///
  /// In ja, this message translates to:
  /// **'数字だけ入力（例: 35）。35A なども自動で判定します。'**
  String get busNumberHint;

  /// No description provided for @ridingLabel.
  ///
  /// In ja, this message translates to:
  /// **'乗車中'**
  String get ridingLabel;

  /// No description provided for @startRiding.
  ///
  /// In ja, this message translates to:
  /// **'乗車開始'**
  String get startRiding;

  /// No description provided for @getOff.
  ///
  /// In ja, this message translates to:
  /// **'降車'**
  String get getOff;

  /// No description provided for @distanceLeft.
  ///
  /// In ja, this message translates to:
  /// **'あと'**
  String get distanceLeft;

  /// No description provided for @tableTapHint.
  ///
  /// In ja, this message translates to:
  /// **'タップで地図、長押しで乗車または降車'**
  String get tableTapHint;

  /// No description provided for @pickOnMap.
  ///
  /// In ja, this message translates to:
  /// **'地図から選択'**
  String get pickOnMap;

  /// No description provided for @chooseVariant.
  ///
  /// In ja, this message translates to:
  /// **'系統を選択'**
  String get chooseVariant;

  /// No description provided for @busNumberHeader.
  ///
  /// In ja, this message translates to:
  /// **'バス番号'**
  String get busNumberHeader;

  /// No description provided for @transfersHeader.
  ///
  /// In ja, this message translates to:
  /// **'乗換回数'**
  String get transfersHeader;

  /// No description provided for @sectionArchive.
  ///
  /// In ja, this message translates to:
  /// **'保管庫'**
  String get sectionArchive;

  /// No description provided for @archiveCount.
  ///
  /// In ja, this message translates to:
  /// **'保管庫の路線: {count} 件'**
  String archiveCount(int count);

  /// No description provided for @archiveRestore.
  ///
  /// In ja, this message translates to:
  /// **'保管庫から復元'**
  String get archiveRestore;

  /// No description provided for @archiveExport.
  ///
  /// In ja, this message translates to:
  /// **'保管庫を書き出し'**
  String get archiveExport;

  /// No description provided for @pickerTitleOrigin.
  ///
  /// In ja, this message translates to:
  /// **'出発地を選ぶ'**
  String get pickerTitleOrigin;

  /// No description provided for @pickerLongPressHintOrigin.
  ///
  /// In ja, this message translates to:
  /// **'地図を長押しして出発地を決めます'**
  String get pickerLongPressHintOrigin;

  /// No description provided for @roleOrigin.
  ///
  /// In ja, this message translates to:
  /// **'出発地'**
  String get roleOrigin;

  /// No description provided for @roleDestination.
  ///
  /// In ja, this message translates to:
  /// **'目的地'**
  String get roleDestination;

  /// No description provided for @manualOriginLabel.
  ///
  /// In ja, this message translates to:
  /// **'出発地: {name}'**
  String manualOriginLabel(String name);

  /// No description provided for @clearManualOrigin.
  ///
  /// In ja, this message translates to:
  /// **'手動出発地をクリア'**
  String get clearManualOrigin;

  /// No description provided for @pickOriginOnMap.
  ///
  /// In ja, this message translates to:
  /// **'出発地を地図から選択'**
  String get pickOriginOnMap;

  /// No description provided for @active.
  ///
  /// In ja, this message translates to:
  /// **'設定中'**
  String get active;

  /// No description provided for @addPlace.
  ///
  /// In ja, this message translates to:
  /// **'場所を追加'**
  String get addPlace;

  /// No description provided for @alertAlarm.
  ///
  /// In ja, this message translates to:
  /// **'アラーム通知'**
  String get alertAlarm;

  /// No description provided for @alertFollowSystemVolume.
  ///
  /// In ja, this message translates to:
  /// **'システム音量に従う'**
  String get alertFollowSystemVolume;

  /// No description provided for @alertNotification.
  ///
  /// In ja, this message translates to:
  /// **'通知'**
  String get alertNotification;

  /// No description provided for @alertNotificationFooter.
  ///
  /// In ja, this message translates to:
  /// **'降車停に近づいたとき、画面にアラートを出します。アプリが裏にあるときは通知で知らせます。'**
  String get alertNotificationFooter;

  /// No description provided for @alertSound.
  ///
  /// In ja, this message translates to:
  /// **'サウンド'**
  String get alertSound;

  /// No description provided for @alertVibration.
  ///
  /// In ja, this message translates to:
  /// **'バイブレーション'**
  String get alertVibration;

  /// No description provided for @alertVibrationStrength.
  ///
  /// In ja, this message translates to:
  /// **'バイブの強さ'**
  String get alertVibrationStrength;

  /// No description provided for @arrivalAlerts.
  ///
  /// In ja, this message translates to:
  /// **'到着アラート'**
  String get arrivalAlerts;

  /// No description provided for @cancelNavigation.
  ///
  /// In ja, this message translates to:
  /// **'ナビを中止'**
  String get cancelNavigation;

  /// No description provided for @cancelNavigationConfirm.
  ///
  /// In ja, this message translates to:
  /// **'行き先をやめますか？乗車中の場合は降車扱いになります。'**
  String get cancelNavigationConfirm;

  /// No description provided for @cannotBeUndone.
  ///
  /// In ja, this message translates to:
  /// **'この操作は取り消せません。'**
  String get cannotBeUndone;

  /// No description provided for @choosePlaceAgain.
  ///
  /// In ja, this message translates to:
  /// **'場所を選び直す'**
  String get choosePlaceAgain;

  /// No description provided for @chooseSound.
  ///
  /// In ja, this message translates to:
  /// **'サウンドを選択'**
  String get chooseSound;

  /// No description provided for @clear.
  ///
  /// In ja, this message translates to:
  /// **'クリア'**
  String get clear;

  /// No description provided for @clearHistory.
  ///
  /// In ja, this message translates to:
  /// **'履歴を消去'**
  String get clearHistory;

  /// No description provided for @clearHistoryConfirm.
  ///
  /// In ja, this message translates to:
  /// **'履歴をすべて消去しますか？'**
  String get clearHistoryConfirm;

  /// No description provided for @clearHistoryFooter.
  ///
  /// In ja, this message translates to:
  /// **'目的地の履歴をすべて消去します。'**
  String get clearHistoryFooter;

  /// No description provided for @currentDestination.
  ///
  /// In ja, this message translates to:
  /// **'現在の目的地'**
  String get currentDestination;

  /// No description provided for @delete.
  ///
  /// In ja, this message translates to:
  /// **'削除'**
  String get delete;

  /// No description provided for @destinationHistory.
  ///
  /// In ja, this message translates to:
  /// **'目的地の履歴'**
  String get destinationHistory;

  /// No description provided for @developerMenu.
  ///
  /// In ja, this message translates to:
  /// **'🛠 開発者メニュー'**
  String get developerMenu;

  /// No description provided for @distanceAlertBody.
  ///
  /// In ja, this message translates to:
  /// **'{meters}m でアラート'**
  String distanceAlertBody(int meters);

  /// No description provided for @distanceAlertMeters.
  ///
  /// In ja, this message translates to:
  /// **'距離（m）'**
  String get distanceAlertMeters;

  /// No description provided for @distanceAlertN.
  ///
  /// In ja, this message translates to:
  /// **'距離アラート {n}'**
  String distanceAlertN(int n);

  /// No description provided for @distanceAlertTitle.
  ///
  /// In ja, this message translates to:
  /// **'距離アラート'**
  String get distanceAlertTitle;

  /// No description provided for @distanceAlerts.
  ///
  /// In ja, this message translates to:
  /// **'距離アラート'**
  String get distanceAlerts;

  /// No description provided for @distanceAlertsFooter.
  ///
  /// In ja, this message translates to:
  /// **'降車バス停まで設定した距離以内に入ったらアラートします。遠い順にアラームが 1〜3 回鳴ります。'**
  String get distanceAlertsFooter;

  /// No description provided for @done.
  ///
  /// In ja, this message translates to:
  /// **'完了'**
  String get done;

  /// No description provided for @edit.
  ///
  /// In ja, this message translates to:
  /// **'編集'**
  String get edit;

  /// No description provided for @help.
  ///
  /// In ja, this message translates to:
  /// **'ヘルプ'**
  String get help;

  /// No description provided for @hideKeypad.
  ///
  /// In ja, this message translates to:
  /// **'テンキーを非表示'**
  String get hideKeypad;

  /// No description provided for @history.
  ///
  /// In ja, this message translates to:
  /// **'履歴'**
  String get history;

  /// No description provided for @historyEmpty.
  ///
  /// In ja, this message translates to:
  /// **'履歴がありません'**
  String get historyEmpty;

  /// No description provided for @historyEmptyDetail.
  ///
  /// In ja, this message translates to:
  /// **'目的地を設定すると、ここに履歴として表示されます。'**
  String get historyEmptyDetail;

  /// No description provided for @historyTapFooter.
  ///
  /// In ja, this message translates to:
  /// **'タップすると、その目的地を設定します。'**
  String get historyTapFooter;

  /// No description provided for @iapLoadFailed.
  ///
  /// In ja, this message translates to:
  /// **'商品の読み込みに失敗しました'**
  String get iapLoadFailed;

  /// No description provided for @iapLoading.
  ///
  /// In ja, this message translates to:
  /// **'商品を読み込み中…'**
  String get iapLoading;

  /// No description provided for @iapPending.
  ///
  /// In ja, this message translates to:
  /// **'購入が保留中です'**
  String get iapPending;

  /// No description provided for @iapProductMissing.
  ///
  /// In ja, this message translates to:
  /// **'商品が見つかりません'**
  String get iapProductMissing;

  /// No description provided for @iapPurchaseFailed.
  ///
  /// In ja, this message translates to:
  /// **'購入に失敗しました'**
  String get iapPurchaseFailed;

  /// No description provided for @iapReload.
  ///
  /// In ja, this message translates to:
  /// **'商品を再読み込み'**
  String get iapReload;

  /// No description provided for @iapRestoreFailed.
  ///
  /// In ja, this message translates to:
  /// **'復元に失敗しました'**
  String get iapRestoreFailed;

  /// No description provided for @itemCount.
  ///
  /// In ja, this message translates to:
  /// **'{count}件'**
  String itemCount(int count);

  /// No description provided for @keyFeedback.
  ///
  /// In ja, this message translates to:
  /// **'キーパッドのフィードバック'**
  String get keyFeedback;

  /// No description provided for @keyFeedbackClick.
  ///
  /// In ja, this message translates to:
  /// **'クリック音'**
  String get keyFeedbackClick;

  /// No description provided for @keyFeedbackFooter.
  ///
  /// In ja, this message translates to:
  /// **'テンキーを押したときの音と振動を調整します。'**
  String get keyFeedbackFooter;

  /// No description provided for @keyFeedbackHaptic.
  ///
  /// In ja, this message translates to:
  /// **'バイブレーション'**
  String get keyFeedbackHaptic;

  /// No description provided for @keyFeedbackHapticStrength.
  ///
  /// In ja, this message translates to:
  /// **'バイブの強さ'**
  String get keyFeedbackHapticStrength;

  /// No description provided for @keypadAppend.
  ///
  /// In ja, this message translates to:
  /// **'結果表示後も数字を継ぎ足す'**
  String get keypadAppend;

  /// No description provided for @keypadClearBeforeNew.
  ///
  /// In ja, this message translates to:
  /// **'結果表示後はクリアして新規入力'**
  String get keypadClearBeforeNew;

  /// No description provided for @keypadInput.
  ///
  /// In ja, this message translates to:
  /// **'テンキー入力'**
  String get keypadInput;

  /// No description provided for @keypadInputFooter.
  ///
  /// In ja, this message translates to:
  /// **'判定結果が出たあと（⏎ のあと）、テンキーで数字を押したときの動作を選べます。'**
  String get keypadInputFooter;

  /// No description provided for @labelHome.
  ///
  /// In ja, this message translates to:
  /// **'自宅'**
  String get labelHome;

  /// No description provided for @labelSchool.
  ///
  /// In ja, this message translates to:
  /// **'学校'**
  String get labelSchool;

  /// No description provided for @labelWork.
  ///
  /// In ja, this message translates to:
  /// **'会社'**
  String get labelWork;

  /// No description provided for @language.
  ///
  /// In ja, this message translates to:
  /// **'言語'**
  String get language;

  /// No description provided for @languageFooter.
  ///
  /// In ja, this message translates to:
  /// **'アプリの表示言語を変更できます。'**
  String get languageFooter;

  /// No description provided for @languageSystem.
  ///
  /// In ja, this message translates to:
  /// **'端末の設定に従う'**
  String get languageSystem;

  /// No description provided for @lineMap.
  ///
  /// In ja, this message translates to:
  /// **'路線図'**
  String get lineMap;

  /// No description provided for @longPressToRegister.
  ///
  /// In ja, this message translates to:
  /// **'長押しで登録'**
  String get longPressToRegister;

  /// No description provided for @longPressToRegisterFooter.
  ///
  /// In ja, this message translates to:
  /// **'長押しで、現在の目的地をそのまま登録できます。'**
  String get longPressToRegisterFooter;

  /// No description provided for @place.
  ///
  /// In ja, this message translates to:
  /// **'場所'**
  String get place;

  /// No description provided for @placeFooter.
  ///
  /// In ja, this message translates to:
  /// **'駅名・住所・施設名で検索するか、地図を長押しして選びます。'**
  String get placeFooter;

  /// No description provided for @placeName.
  ///
  /// In ja, this message translates to:
  /// **'名前'**
  String get placeName;

  /// No description provided for @placeNameFooter.
  ///
  /// In ja, this message translates to:
  /// **'一覧に表示される名前です。自宅・職場など、わかりやすい名前にしてください。'**
  String get placeNameFooter;

  /// No description provided for @placeNamePlaceholder.
  ///
  /// In ja, this message translates to:
  /// **'表示名（例: 自宅）'**
  String get placeNamePlaceholder;

  /// No description provided for @planCurrent.
  ///
  /// In ja, this message translates to:
  /// **'現在のプラン'**
  String get planCurrent;

  /// No description provided for @planFree.
  ///
  /// In ja, this message translates to:
  /// **'FREE'**
  String get planFree;

  /// No description provided for @planFreeDescription.
  ///
  /// In ja, this message translates to:
  /// **'現在は FREE プランです。PREMIUM にアップグレードすると、登録済みの場所と履歴が無制限になります。'**
  String get planFreeDescription;

  /// No description provided for @planFreeLimitFooter.
  ///
  /// In ja, this message translates to:
  /// **'FREEプランでは、履歴と登録済みの場所はそれぞれ{count}件までです。PREMIUMにアップグレードすると無制限に保存できます。'**
  String planFreeLimitFooter(int count);

  /// No description provided for @planManagement.
  ///
  /// In ja, this message translates to:
  /// **'プラン管理'**
  String get planManagement;

  /// No description provided for @planNothingToRestore.
  ///
  /// In ja, this message translates to:
  /// **'復元できる購入が見つかりませんでした。'**
  String get planNothingToRestore;

  /// No description provided for @planPremium.
  ///
  /// In ja, this message translates to:
  /// **'PREMIUM'**
  String get planPremium;

  /// No description provided for @planPremiumLimitFooter.
  ///
  /// In ja, this message translates to:
  /// **'PREMIUMプランでは、履歴と登録済みの場所を無制限に保存できます。'**
  String get planPremiumLimitFooter;

  /// No description provided for @planRestore.
  ///
  /// In ja, this message translates to:
  /// **'購入を復元'**
  String get planRestore;

  /// No description provided for @planRestoreFooter.
  ///
  /// In ja, this message translates to:
  /// **'ストアで PREMIUM を購入済みの場合は、ここから復元できます。'**
  String get planRestoreFooter;

  /// No description provided for @planRestored.
  ///
  /// In ja, this message translates to:
  /// **'購入を復元しました。'**
  String get planRestored;

  /// No description provided for @planSwitchDescription.
  ///
  /// In ja, this message translates to:
  /// **'デバッグビルドだけの切り替えです。ストアの購入は変わりません。'**
  String get planSwitchDescription;

  /// No description provided for @planUpgrade.
  ///
  /// In ja, this message translates to:
  /// **'PREMIUMにアップグレード'**
  String get planUpgrade;

  /// No description provided for @planUpgradeDone.
  ///
  /// In ja, this message translates to:
  /// **'プレミアムプランへのアップグレードが完了しました！'**
  String get planUpgradeDone;

  /// No description provided for @preview.
  ///
  /// In ja, this message translates to:
  /// **'プレビュー'**
  String get preview;

  /// No description provided for @privacyConsent.
  ///
  /// In ja, this message translates to:
  /// **'同意の管理'**
  String get privacyConsent;

  /// No description provided for @privacyConsentOff.
  ///
  /// In ja, this message translates to:
  /// **'同意していません。路線データの取得はしません。'**
  String get privacyConsentOff;

  /// No description provided for @privacyConsentOn.
  ///
  /// In ja, this message translates to:
  /// **'同意しています。'**
  String get privacyConsentOn;

  /// No description provided for @privacyDeleteAll.
  ///
  /// In ja, this message translates to:
  /// **'すべてのデータを削除'**
  String get privacyDeleteAll;

  /// No description provided for @privacyDeleteAllConfirm.
  ///
  /// In ja, this message translates to:
  /// **'保存データを削除しますか？'**
  String get privacyDeleteAllConfirm;

  /// No description provided for @privacyDeleteAllDetail.
  ///
  /// In ja, this message translates to:
  /// **'目的地、目的地の履歴、登録済みの場所、外部送信への同意と路線データを削除します。購入状態・一般設定・路線の保管庫は削除されません。'**
  String get privacyDeleteAllDetail;

  /// No description provided for @privacyFooter.
  ///
  /// In ja, this message translates to:
  /// **'データの送信・保存・削除について確認できます。'**
  String get privacyFooter;

  /// No description provided for @privacyRecipients.
  ///
  /// In ja, this message translates to:
  /// **'送信先・項目・目的'**
  String get privacyRecipients;

  /// No description provided for @privacyRecipientsBody.
  ///
  /// In ja, this message translates to:
  /// **'・OpenStreetMap の Overpass API（overpass-api.de、Kumi Systems、Mail.ru）: 現在地の座標と検索半径、路線 ID。路線と停留所の取得のため。同意したときだけ送ります。\n・地図タイル（OpenStreetMap、OSM France）: 表示中の地図の範囲。地図の表示のため。\n・Google マップ（API キーがあり、設定でオンのときだけ）: 表示中の地図の範囲。地図の表示のため。\n・地名検索（Nominatim、Photon）: 入力した地名と、近くを優先するための現在地付近の座標。目的地の検索のため。\n・App Store / Google Play: PREMIUM の購入と復元。\nバスの判定と番号表は端末の中だけで計算し、Google には何も送りません。'**
  String get privacyRecipientsBody;

  /// No description provided for @privacyStorage.
  ///
  /// In ja, this message translates to:
  /// **'端末での保存'**
  String get privacyStorage;

  /// No description provided for @privacyStorageBody.
  ///
  /// In ja, this message translates to:
  /// **'路線データ、その保管庫、目的地、目的地の履歴、登録済みの場所、設定はこの端末に保存します。iCloud 同期をオンにしたときだけ、路線データを自分の iCloud Drive にも保存します。'**
  String get privacyStorageBody;

  /// No description provided for @privacyTitle.
  ///
  /// In ja, this message translates to:
  /// **'プライバシーとデータ'**
  String get privacyTitle;

  /// No description provided for @routeBoardHint.
  ///
  /// In ja, this message translates to:
  /// **'番号を長押しで乗車・降車'**
  String get routeBoardHint;

  /// No description provided for @routeCandidates.
  ///
  /// In ja, this message translates to:
  /// **'路線候補'**
  String get routeCandidates;

  /// No description provided for @routeCandidatesHint.
  ///
  /// In ja, this message translates to:
  /// **'バス番号に一致する路線を選んでください。近い順です。'**
  String get routeCandidatesHint;

  /// No description provided for @routeDataAttribution.
  ///
  /// In ja, this message translates to:
  /// **'路線データ © OpenStreetMap contributors'**
  String get routeDataAttribution;

  /// No description provided for @routeList.
  ///
  /// In ja, this message translates to:
  /// **'路線一覧'**
  String get routeList;

  /// No description provided for @routeListEmpty.
  ///
  /// In ja, this message translates to:
  /// **'路線データがありません'**
  String get routeListEmpty;

  /// No description provided for @routeListEmptyDetail.
  ///
  /// In ja, this message translates to:
  /// **'設定で路線情報をダウンロードすると、ここに一覧が出ます。'**
  String get routeListEmptyDetail;

  /// No description provided for @routeMapEmpty.
  ///
  /// In ja, this message translates to:
  /// **'バス番号を入力して路線を検索'**
  String get routeMapEmpty;

  /// No description provided for @routeMapErrorTitle.
  ///
  /// In ja, this message translates to:
  /// **'路線図エラー'**
  String get routeMapErrorTitle;

  /// No description provided for @routeMapNoLocation.
  ///
  /// In ja, this message translates to:
  /// **'近い路線から並べるには現在地が必要です。'**
  String get routeMapNoLocation;

  /// No description provided for @routeSearchNone.
  ///
  /// In ja, this message translates to:
  /// **'「{number}」に一致する路線が端末の路線データにありません。'**
  String routeSearchNone(String number);

  /// No description provided for @save.
  ///
  /// In ja, this message translates to:
  /// **'保存'**
  String get save;

  /// No description provided for @savedPlaces.
  ///
  /// In ja, this message translates to:
  /// **'登録済みの場所'**
  String get savedPlaces;

  /// No description provided for @savedPlacesEmpty.
  ///
  /// In ja, this message translates to:
  /// **'登録済みの場所はありません'**
  String get savedPlacesEmpty;

  /// No description provided for @savedPlacesEmptyDetail.
  ///
  /// In ja, this message translates to:
  /// **'自宅やよく行く場所を登録すると、ワンタップで目的地に設定できます。右上の＋から追加できます。'**
  String get savedPlacesEmptyDetail;

  /// No description provided for @savedPlacesFooter.
  ///
  /// In ja, this message translates to:
  /// **'タップで目的地に設定。左スワイプで削除、鉛筆で編集できます。'**
  String get savedPlacesFooter;

  /// No description provided for @savedPlacesFreeLimit.
  ///
  /// In ja, this message translates to:
  /// **'FREEプランでは登録できる場所は{count}件までです。'**
  String savedPlacesFreeLimit(int count);

  /// No description provided for @searchFromHistory.
  ///
  /// In ja, this message translates to:
  /// **'履歴から探す'**
  String get searchFromHistory;

  /// No description provided for @searchFromSavedPlaces.
  ///
  /// In ja, this message translates to:
  /// **'登録地から探す'**
  String get searchFromSavedPlaces;

  /// No description provided for @showKeypad.
  ///
  /// In ja, this message translates to:
  /// **'テンキーを表示'**
  String get showKeypad;

  /// No description provided for @soundBell.
  ///
  /// In ja, this message translates to:
  /// **'ベル'**
  String get soundBell;

  /// No description provided for @soundChime.
  ///
  /// In ja, this message translates to:
  /// **'チャイム'**
  String get soundChime;

  /// No description provided for @soundConfirm.
  ///
  /// In ja, this message translates to:
  /// **'確認音'**
  String get soundConfirm;

  /// No description provided for @soundDing.
  ///
  /// In ja, this message translates to:
  /// **'ディン'**
  String get soundDing;

  /// No description provided for @soundMessage.
  ///
  /// In ja, this message translates to:
  /// **'メッセージ'**
  String get soundMessage;

  /// No description provided for @soundTiptoes.
  ///
  /// In ja, this message translates to:
  /// **'つま先'**
  String get soundTiptoes;

  /// No description provided for @soundTock.
  ///
  /// In ja, this message translates to:
  /// **'タック'**
  String get soundTock;

  /// No description provided for @soundTriTone.
  ///
  /// In ja, this message translates to:
  /// **'三連音'**
  String get soundTriTone;

  /// No description provided for @strengthHeavy.
  ///
  /// In ja, this message translates to:
  /// **'強め'**
  String get strengthHeavy;

  /// No description provided for @strengthLight.
  ///
  /// In ja, this message translates to:
  /// **'弱め'**
  String get strengthLight;

  /// No description provided for @strengthMedium.
  ///
  /// In ja, this message translates to:
  /// **'普通'**
  String get strengthMedium;

  /// No description provided for @trackingNotice.
  ///
  /// In ja, this message translates to:
  /// **'到着アラートのため乗車中の位置を追跡しています。'**
  String get trackingNotice;

  /// No description provided for @unlimited.
  ///
  /// In ja, this message translates to:
  /// **'無制限'**
  String get unlimited;

  /// No description provided for @volume.
  ///
  /// In ja, this message translates to:
  /// **'音量'**
  String get volume;

  /// No description provided for @wrongDirectionBody.
  ///
  /// In ja, this message translates to:
  /// **'このバスは逆方向に走っている可能性があります。乗車前に路線を確認してください。'**
  String get wrongDirectionBody;

  /// No description provided for @wrongDirectionBodyRouteMap.
  ///
  /// In ja, this message translates to:
  /// **'このバスは目的地に向かっていない可能性があります。次のバス停で降りてください。'**
  String get wrongDirectionBodyRouteMap;

  /// No description provided for @wrongDirectionTitle.
  ///
  /// In ja, this message translates to:
  /// **'逆方向です'**
  String get wrongDirectionTitle;

  /// No description provided for @helpIntro.
  ///
  /// In ja, this message translates to:
  /// **'起動するとマトリクスです。行き先を設定し、バス番号表から乗れるバスを選べます。番号判定のキーパッドは … → 番号入力、または画面左端から右へスワイプで切り替えます。'**
  String get helpIntro;

  /// No description provided for @helpBasics.
  ///
  /// In ja, this message translates to:
  /// **'基本操作'**
  String get helpBasics;

  /// No description provided for @helpResults.
  ///
  /// In ja, this message translates to:
  /// **'結果の見方'**
  String get helpResults;

  /// No description provided for @helpRoutes.
  ///
  /// In ja, this message translates to:
  /// **'路線を見る'**
  String get helpRoutes;

  /// No description provided for @helpTroubleshooting.
  ///
  /// In ja, this message translates to:
  /// **'トラブルシュート'**
  String get helpTroubleshooting;

  /// No description provided for @helpTopTitle.
  ///
  /// In ja, this message translates to:
  /// **'マトリクス'**
  String get helpTopTitle;

  /// No description provided for @helpTopBody.
  ///
  /// In ja, this message translates to:
  /// **'起動時の画面です。行き先・現在地・距離・バス番号表が並びます。キーパッドで番号判定したいときは … → 番号入力。画面左端から右へスワイプでも切り替えられます。マトリクスに戻るときは … → マトリクス、またはもう一度左端から右へスワイプします。'**
  String get helpTopBody;

  /// No description provided for @helpDestinationTitle.
  ///
  /// In ja, this message translates to:
  /// **'目的地を設定'**
  String get helpDestinationTitle;

  /// No description provided for @helpDestinationBody.
  ///
  /// In ja, this message translates to:
  /// **'行き先バーをタップすると地図のシートが開きます。地名検索か地図の長押しで選ぶほか、「履歴から探す」「登録地から探す」からも選べます。シート上部で出発地と目的地を切り替えられます。'**
  String get helpDestinationBody;

  /// No description provided for @helpLocationTitle.
  ///
  /// In ja, this message translates to:
  /// **'現在地と出発地'**
  String get helpLocationTitle;

  /// No description provided for @helpLocationBody.
  ///
  /// In ja, this message translates to:
  /// **'起動時に位置情報の許可を求めます。現在地バーの ↻ で更新、地図アイコンで出発地を地図から指定できます。指定した出発地は × で現在地に戻せます。乗車中の距離はいつも GPS の現在地から測ります。'**
  String get helpLocationBody;

  /// No description provided for @helpSavedPlacesTitle.
  ///
  /// In ja, this message translates to:
  /// **'場所を登録'**
  String get helpSavedPlacesTitle;

  /// No description provided for @helpSavedPlacesBody.
  ///
  /// In ja, this message translates to:
  /// **'行き先シートの「登録地から探す」から、自宅やよく行く場所を登録できます。タップすると目的地に設定されます。今の目的地は長押しでそのまま登録できます。'**
  String get helpSavedPlacesBody;

  /// No description provided for @helpBusNumberTitle.
  ///
  /// In ja, this message translates to:
  /// **'バス番号を入力'**
  String get helpBusNumberTitle;

  /// No description provided for @helpBusNumberBody.
  ///
  /// In ja, this message translates to:
  /// **'表に無い番号を判定したいときだけ … → 番号入力（または左端から右スワイプ）でキーパッドを開き、数字だけ入力します（例: 35）。行き先ルートと照合し、乗換地点まで行ける場合は乗車可とします。'**
  String get helpBusNumberBody;

  /// No description provided for @helpTableTitle.
  ///
  /// In ja, this message translates to:
  /// **'バス番号表'**
  String get helpTableTitle;

  /// No description provided for @helpTableBody.
  ///
  /// In ja, this message translates to:
  /// **'方向と乗換回数ごとに、乗れるバス番号が並びます。タップで路線図、長押しで乗車と降車の切り替えです。乗車中の番号はオレンジになります。'**
  String get helpTableBody;

  /// No description provided for @helpBoardTitle.
  ///
  /// In ja, this message translates to:
  /// **'乗車開始'**
  String get helpBoardTitle;

  /// No description provided for @helpBoardBody.
  ///
  /// In ja, this message translates to:
  /// **'番号入力でバス番号を入力すると、行き先までのルートと照合します。乗れる系統があれば黄色で「35A だったら乗ってください！」のように表示され、「乗車開始」で乗車中になります。'**
  String get helpBoardBody;

  /// No description provided for @helpSkipTitle.
  ///
  /// In ja, this message translates to:
  /// **'見送ってください！'**
  String get helpSkipTitle;

  /// No description provided for @helpSkipBody.
  ///
  /// In ja, this message translates to:
  /// **'行き先ルートに、入力した数字の系統が含まれない場合は、赤色で「見送ってください！」と表示されます。'**
  String get helpSkipBody;

  /// No description provided for @helpDistanceTitle.
  ///
  /// In ja, this message translates to:
  /// **'距離の色'**
  String get helpDistanceTitle;

  /// No description provided for @helpDistanceBody.
  ///
  /// In ja, this message translates to:
  /// **'未乗車のときは目的地までの直線距離、乗車中は今乗っているバスの降車バス停までの直線距離です。3km以上は青、1km以上は緑、500m以上は黄、200m以上は橙、200m未満は赤です。乗車中に距離バッジをタップすると、今のルート図が開きます。距離バッジを長押しするとナビ中止（行き先も消えます）。行き先を設定せずに路線図から乗車した場合は「—」と表示され、距離は出ません。'**
  String get helpDistanceBody;

  /// No description provided for @helpRidingTitle.
  ///
  /// In ja, this message translates to:
  /// **'乗車中モード'**
  String get helpRidingTitle;

  /// No description provided for @helpRidingBody.
  ///
  /// In ja, this message translates to:
  /// **'バス番号を長押しすると乗車中になります。同じ番号をもう一度長押しすると降車（乗換用）します。乗車中は降車バス停までの距離で到着アラートが鳴り、画面がオフでも位置の追跡を続けます。逆方向に乗っていそうなときは警告します。'**
  String get helpRidingBody;

  /// No description provided for @helpLineMapTitle.
  ///
  /// In ja, this message translates to:
  /// **'路線図'**
  String get helpLineMapTitle;

  /// No description provided for @helpLineMapBody.
  ///
  /// In ja, this message translates to:
  /// **'… → 路線図 で、端末に保存した路線データからバス番号で路線を探して地図に出します。一覧ボタンから保存済みの路線も選べます。番号バッジを長押しすると乗車・降車します（降車は終点）。'**
  String get helpLineMapBody;

  /// No description provided for @helpSettingsTitle.
  ///
  /// In ja, this message translates to:
  /// **'設定とアラート'**
  String get helpSettingsTitle;

  /// No description provided for @helpSettingsBody.
  ///
  /// In ja, this message translates to:
  /// **'… → 設定 から、言語・テンキー入力・キーパッドの音と振動・到着アラート・路線データを変更できます。到着アラートは降車バス停までの距離で最大3段階設定でき、遠い順にアラームが1〜3回鳴ります。アプリが裏にあるときは通知で知らせます。'**
  String get helpSettingsBody;

  /// No description provided for @helpPlanTitle.
  ///
  /// In ja, this message translates to:
  /// **'プラン管理'**
  String get helpPlanTitle;

  /// No description provided for @helpPlanBody.
  ///
  /// In ja, this message translates to:
  /// **'… → プラン管理 から現在のプランを確認し、PREMIUM にアップグレードしたり、購入を復元できます。FREEプランは登録済みの場所{count}件・履歴{count}件まで。PREMIUMは無制限です。'**
  String helpPlanBody(int count);

  /// No description provided for @helpNoRouteTitle.
  ///
  /// In ja, this message translates to:
  /// **'ルートが見つからない'**
  String get helpNoRouteTitle;

  /// No description provided for @helpNoRouteBody.
  ///
  /// In ja, this message translates to:
  /// **'設定で路線データをダウンロードしたか、現在地と目的地が同じ地域にあるか確認してください。路線データは現在地の周辺を取得します。'**
  String get helpNoRouteBody;

  /// No description provided for @helpNetworkTitle.
  ///
  /// In ja, this message translates to:
  /// **'通信エラー'**
  String get helpNetworkTitle;

  /// No description provided for @helpNetworkBody.
  ///
  /// In ja, this message translates to:
  /// **'Wi‑Fi またはモバイルデータを確認し、もう一度試してください。バスの判定は端末内の路線データで行うため、オフラインでも使えます。'**
  String get helpNetworkBody;

  /// No description provided for @developerScreen.
  ///
  /// In ja, this message translates to:
  /// **'開発者画面'**
  String get developerScreen;

  /// No description provided for @devAppInfo.
  ///
  /// In ja, this message translates to:
  /// **'アプリと端末'**
  String get devAppInfo;

  /// No description provided for @devLogs.
  ///
  /// In ja, this message translates to:
  /// **'ログ'**
  String get devLogs;

  /// No description provided for @devLogsFooter.
  ///
  /// In ja, this message translates to:
  /// **'不具合を知らせるときは「ログを送る」から、メールなどで送ってください。先頭に端末とアプリの情報が付きます。位置は約100mに丸めて記録しています。'**
  String get devLogsFooter;

  /// No description provided for @devLogSend.
  ///
  /// In ja, this message translates to:
  /// **'ログを送る'**
  String get devLogSend;

  /// No description provided for @devLogSize.
  ///
  /// In ja, this message translates to:
  /// **'ファイル {kb}KB・画面 {count}件'**
  String devLogSize(int kb, int count);

  /// No description provided for @devLogCopy.
  ///
  /// In ja, this message translates to:
  /// **'ログをコピー'**
  String get devLogCopy;

  /// No description provided for @devLogCopied.
  ///
  /// In ja, this message translates to:
  /// **'ログをクリップボードにコピーしました。'**
  String get devLogCopied;

  /// No description provided for @devVerboseLog.
  ///
  /// In ja, this message translates to:
  /// **'詳細ログ'**
  String get devVerboseLog;

  /// No description provided for @devVerboseLogDetail.
  ///
  /// In ja, this message translates to:
  /// **'位置の更新や降車停までの距離も記録します。乗車中の不具合を調べるときにオンにしてください。'**
  String get devVerboseLogDetail;

  /// No description provided for @devLogClear.
  ///
  /// In ja, this message translates to:
  /// **'ログを消去'**
  String get devLogClear;

  /// No description provided for @devLogClearConfirm.
  ///
  /// In ja, this message translates to:
  /// **'ログをすべて消去しますか？'**
  String get devLogClearConfirm;

  /// No description provided for @devTests.
  ///
  /// In ja, this message translates to:
  /// **'テスト'**
  String get devTests;

  /// No description provided for @devTestAlarm.
  ///
  /// In ja, this message translates to:
  /// **'到着アラームを鳴らす'**
  String get devTestAlarm;

  /// No description provided for @devTestNotification.
  ///
  /// In ja, this message translates to:
  /// **'5秒後に通知を出す'**
  String get devTestNotification;

  /// No description provided for @devTestNotificationDetail.
  ///
  /// In ja, this message translates to:
  /// **'押したあと画面を消すと、裏での通知を確かめられます。'**
  String get devTestNotificationDetail;

  /// No description provided for @devRecentLogs.
  ///
  /// In ja, this message translates to:
  /// **'最近のログ（新しい順）'**
  String get devRecentLogs;

  /// No description provided for @devNoLogs.
  ///
  /// In ja, this message translates to:
  /// **'ログはまだありません'**
  String get devNoLogs;

  /// No description provided for @devTapsLeft.
  ///
  /// In ja, this message translates to:
  /// **'あと {count} 回で開発者画面'**
  String devTapsLeft(int count);

  /// No description provided for @devLogSubject.
  ///
  /// In ja, this message translates to:
  /// **'osmBus ログ'**
  String get devLogSubject;

  /// No description provided for @devLogShareText.
  ///
  /// In ja, this message translates to:
  /// **'osmBus のログを送ります。'**
  String get devLogShareText;

  /// No description provided for @devLogSendFailed.
  ///
  /// In ja, this message translates to:
  /// **'ログを書き出せませんでした: {reason}'**
  String devLogSendFailed(String reason);

  /// No description provided for @versionLabel.
  ///
  /// In ja, this message translates to:
  /// **'バージョン {version} ({build})'**
  String versionLabel(String version, String build);

  /// No description provided for @sectionMap.
  ///
  /// In ja, this message translates to:
  /// **'地図'**
  String get sectionMap;

  /// No description provided for @useGoogleMaps.
  ///
  /// In ja, this message translates to:
  /// **'Google マップを使う'**
  String get useGoogleMaps;

  /// No description provided for @mapsApiKey.
  ///
  /// In ja, this message translates to:
  /// **'Google Maps API キー'**
  String get mapsApiKey;

  /// No description provided for @mapsKeyUser.
  ///
  /// In ja, this message translates to:
  /// **'設定済み（…{suffix}）'**
  String mapsKeyUser(String suffix);

  /// No description provided for @mapsKeyBundled.
  ///
  /// In ja, this message translates to:
  /// **'アプリに組み込んだキーを使用中'**
  String get mapsKeyBundled;

  /// No description provided for @mapsKeyNone.
  ///
  /// In ja, this message translates to:
  /// **'未設定'**
  String get mapsKeyNone;

  /// No description provided for @mapsKeyRestart.
  ///
  /// In ja, this message translates to:
  /// **'変更はアプリの再起動後に反映されます'**
  String get mapsKeyRestart;

  /// No description provided for @mapsFooter.
  ///
  /// In ja, this message translates to:
  /// **'API キーがあり、オンのときは Google マップで表示します。それ以外は OpenStreetMap の地図です。路線と停留所はどちらも端末内の OSM データです。'**
  String get mapsFooter;

  /// No description provided for @mapsFooterAndroid.
  ///
  /// In ja, this message translates to:
  /// **'Android ではキーをアプリのビルド時に組み込みます（ここでは変えられません）。'**
  String get mapsFooterAndroid;

  /// No description provided for @mapsKeyDialogMessage.
  ///
  /// In ja, this message translates to:
  /// **'Maps SDK for iOS を有効にしたキーを入力します。空にして保存すると削除します。'**
  String get mapsKeyDialogMessage;

  /// No description provided for @transferAt.
  ///
  /// In ja, this message translates to:
  /// **'乗換: {stop}'**
  String transferAt(String stop);

  /// No description provided for @longPressToBoard.
  ///
  /// In ja, this message translates to:
  /// **'長押しで乗車'**
  String get longPressToBoard;

  /// No description provided for @longPressToGetOff.
  ///
  /// In ja, this message translates to:
  /// **'長押しで降車'**
  String get longPressToGetOff;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
