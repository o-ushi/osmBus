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
