// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'osmBus';

  @override
  String get settings => 'Settings';

  @override
  String get reload => 'Reload';

  @override
  String get cancel => 'Cancel';

  @override
  String get ok => 'OK';

  @override
  String get never => 'Never';

  @override
  String get destinationUnset => 'Set a destination';

  @override
  String get destinationLabel => 'Destination';

  @override
  String get destinationPickedPoint => 'Point picked on map';

  @override
  String get tableConsentRequired => 'Agree to use OSM data to see routes';

  @override
  String get noLocation => 'No current location';

  @override
  String get tableCalculating => 'Loading routes…';

  @override
  String get tableNoRoutes =>
      'No routes found for these conditions. Check your location, destination, and route data.';

  @override
  String get noRouteData => 'No route data';

  @override
  String get headerDirection => 'Direction';

  @override
  String get headerDirect => 'Direct';

  @override
  String get headerTransfer1 => '1 transfer';

  @override
  String get headerTransfer2 => '2+ transfers';

  @override
  String transferCount(String count) {
    return 'Transfers $count';
  }

  @override
  String get compassN => 'N';

  @override
  String get compassNE => 'NE';

  @override
  String get compassE => 'E';

  @override
  String get compassSE => 'SE';

  @override
  String get compassS => 'S';

  @override
  String get compassSW => 'SW';

  @override
  String get compassW => 'W';

  @override
  String get compassNW => 'NW';

  @override
  String get enterBusNumber => 'Enter a bus number';

  @override
  String boardVariant(String names) {
    return 'Get on if it\'s $names!';
  }

  @override
  String get doNotBoard => 'Skip this bus!';

  @override
  String alightAt(String stop) {
    return 'Alight at $stop';
  }

  @override
  String estimatedArrival(String time, int minutes) {
    return 'Arrive around $time (estimate, ~$minutes min)';
  }

  @override
  String get directionAny =>
      'Either direction is OK if it goes toward your destination';

  @override
  String directionToward(String direction) {
    return 'Often heading $direction — not required';
  }

  @override
  String get keypadDelete => 'Delete';

  @override
  String get keypadSubmit => 'Check';

  @override
  String ridingNow(String ref) {
    return 'Riding: $ref';
  }

  @override
  String get endRiding => 'End ride';

  @override
  String get sectionData => 'Route data';

  @override
  String get consentTitle => 'Use OpenStreetMap data';

  @override
  String get consentDescription =>
      'Fetch nearby bus routes from the Overpass API and store them on this device.';

  @override
  String get withdrawConsent => 'Withdraw consent and delete data';

  @override
  String get withdrawConfirm => 'This deletes the saved route file. Continue?';

  @override
  String routeCount(int count) {
    return '$count routes';
  }

  @override
  String geometryCount(int count) {
    return '$count with geometry';
  }

  @override
  String lastSaved(String time) {
    return 'Last saved $time';
  }

  @override
  String get downloadAll => 'Download all';

  @override
  String get updateRoutes => 'Update';

  @override
  String progress(int done, int total) {
    return 'Downloading $done/$total';
  }

  @override
  String downloadFinished(int count) {
    return 'Saved $count routes with geometry';
  }

  @override
  String updateFinished(int count) {
    return 'Updated ($count routes with geometry)';
  }

  @override
  String get downloadNoRoutes => 'No routes nearby';

  @override
  String get downloadConsentRequired => 'Consent to use OSM data is required';

  @override
  String downloadFailed(String detail) {
    return 'Download failed: $detail';
  }

  @override
  String get needsLocation => 'Current location is required to download';

  @override
  String get sectionBackup => 'Backup';

  @override
  String get exportBackup => 'Export';

  @override
  String get importBackup => 'Import';

  @override
  String get importChooseMode => 'How to import';

  @override
  String get importReplace => 'Replace';

  @override
  String get importMerge => 'Merge';

  @override
  String importDone(int count) {
    return 'Saved $count routes';
  }

  @override
  String importFailed(String reason) {
    return 'Could not import: $reason';
  }

  @override
  String get sectionSync => 'Sync';

  @override
  String get iCloudSync => 'iCloud sync';

  @override
  String get iCloudOnlyIOS => 'iCloud is iOS only';

  @override
  String get iCloudUnavailable =>
      'iCloud is unavailable (not signed in, or container not set up)';

  @override
  String get syncNow => 'Sync now';

  @override
  String get syncing => 'Syncing…';

  @override
  String lastSynced(String time) {
    return 'Last synced $time';
  }

  @override
  String syncError(String detail) {
    return 'Sync error: $detail';
  }

  @override
  String get sectionTable => 'Number table order';

  @override
  String get sortDirection => 'Direction';

  @override
  String get sortDistance => 'Distance';

  @override
  String get sortTransfers => 'Transfers';

  @override
  String get metricLabel => 'Distance measure';

  @override
  String get metricWalk => 'Walking first';

  @override
  String get metricTotal => 'Total distance';

  @override
  String get sectionLocation => 'Current location';

  @override
  String get locationOk => 'Available';

  @override
  String get locationUnknown => 'Not checked';

  @override
  String get locationDenied => 'Location permission is not granted';

  @override
  String get locationDeniedForever =>
      'Location is denied. Allow it in the Settings app';

  @override
  String get locationServiceDisabled => 'Location services are off';

  @override
  String get openSettings => 'Open Settings';

  @override
  String get retry => 'Retry';

  @override
  String get pickerTitle => 'Choose destination';

  @override
  String get searchHint => 'Search places';

  @override
  String get pickerLongPressHint => 'Long-press the map to set the destination';

  @override
  String get searchFailed => 'Search failed';

  @override
  String routeMapTitle(String ref) {
    return 'Route $ref';
  }

  @override
  String boardAt(String stop) {
    return 'Board at: $stop';
  }

  @override
  String walkMeters(int meters) {
    return 'Walk $meters m';
  }

  @override
  String get busNumberTable => 'Bus Number Table';

  @override
  String currentLocationLabel(String status) {
    return 'Current Location: $status';
  }

  @override
  String get locationAcquired => 'Acquired';

  @override
  String get locationFetching => 'Fetching…';

  @override
  String get locationNotAcquired => 'Not acquired';

  @override
  String get locationNotAllowed =>
      'Location access is not allowed. Please enable it in Settings.';

  @override
  String get menuMainScreen => 'Number entry';

  @override
  String get menuTopScreen => 'Matrix';

  @override
  String get more => 'More';

  @override
  String get busNumberHint =>
      'Enter digits only (e.g. 35). Variants like 35A are detected automatically.';

  @override
  String get ridingLabel => 'Riding';

  @override
  String get startRiding => 'Start riding';

  @override
  String get getOff => 'Get off';

  @override
  String get distanceLeft => 'Left';

  @override
  String get tableTapHint =>
      'Tap to view the route map, long-press to board or alight';

  @override
  String get pickOnMap => 'Pick on map';

  @override
  String get chooseVariant => 'Choose route variant';

  @override
  String get busNumberHeader => 'Bus number';

  @override
  String get transfersHeader => 'Transfers';

  @override
  String get sectionArchive => 'Archive';

  @override
  String archiveCount(int count) {
    return 'Archived routes: $count';
  }

  @override
  String get archiveRestore => 'Restore from archive';

  @override
  String get archiveExport => 'Export archive';

  @override
  String get pickerTitleOrigin => 'Choose origin';

  @override
  String get pickerLongPressHintOrigin =>
      'Long-press the map to set the origin';

  @override
  String get roleOrigin => 'Origin';

  @override
  String get roleDestination => 'Destination';

  @override
  String manualOriginLabel(String name) {
    return 'Origin: $name';
  }

  @override
  String get clearManualOrigin => 'Clear manual origin';

  @override
  String get pickOriginOnMap => 'Choose origin on map';

  @override
  String get active => 'Active';

  @override
  String get addPlace => 'Add place';

  @override
  String get alertAlarm => 'Alarm alerts';

  @override
  String get alertFollowSystemVolume => 'Follow system volume';

  @override
  String get alertNotification => 'Notifications';

  @override
  String get alertNotificationFooter =>
      'Show an alert when approaching your stop. When the app is in the background, a notification is shown instead.';

  @override
  String get alertSound => 'Sound';

  @override
  String get alertVibration => 'Vibration';

  @override
  String get alertVibrationStrength => 'Vibration strength';

  @override
  String get arrivalAlerts => 'Arrival alerts';

  @override
  String get cancelNavigation => 'Cancel navigation';

  @override
  String get cancelNavigationConfirm =>
      'Cancel this trip? If you\'re riding, this counts as getting off.';

  @override
  String get cannotBeUndone => 'This action cannot be undone.';

  @override
  String get choosePlaceAgain => 'Choose a different place';

  @override
  String get chooseSound => 'Choose sound';

  @override
  String get clear => 'Clear';

  @override
  String get clearHistory => 'Clear history';

  @override
  String get clearHistoryConfirm => 'Clear all history?';

  @override
  String get clearHistoryFooter => 'Clear all destination history.';

  @override
  String get currentDestination => 'Current destination';

  @override
  String get delete => 'Delete';

  @override
  String get destinationHistory => 'Destination history';

  @override
  String get developerMenu => '🛠 Developer Menu';

  @override
  String distanceAlertBody(int meters) {
    return 'Alert at $meters m';
  }

  @override
  String get distanceAlertMeters => 'Distance (m)';

  @override
  String distanceAlertN(int n) {
    return 'Distance alert $n';
  }

  @override
  String get distanceAlertTitle => 'Distance alert';

  @override
  String get distanceAlerts => 'Distance alerts';

  @override
  String get distanceAlertsFooter =>
      'Alert when within the set distance of your stop. Alarms ring 1–3 times, from the furthest threshold to the closest.';

  @override
  String get done => 'Done';

  @override
  String get edit => 'Edit';

  @override
  String get help => 'Help';

  @override
  String get hideKeypad => 'Hide keypad';

  @override
  String get history => 'History';

  @override
  String get historyEmpty => 'No history yet';

  @override
  String get historyEmptyDetail =>
      'When you set a destination, it will appear here as history.';

  @override
  String get historyTapFooter => 'Tap to set that destination.';

  @override
  String get iapLoadFailed => 'Could not load products';

  @override
  String get iapLoading => 'Loading products…';

  @override
  String get iapPending => 'Purchase pending approval';

  @override
  String get iapProductMissing => 'Product not found';

  @override
  String get iapPurchaseFailed => 'Purchase failed';

  @override
  String get iapReload => 'Reload products';

  @override
  String get iapRestoreFailed => 'Restore failed';

  @override
  String itemCount(int count) {
    return '$count items';
  }

  @override
  String get keyFeedback => 'Keypad feedback';

  @override
  String get keyFeedbackClick => 'Click sound';

  @override
  String get keyFeedbackFooter =>
      'Adjust sound and vibration when tapping the keypad.';

  @override
  String get keyFeedbackHaptic => 'Haptic feedback';

  @override
  String get keyFeedbackHapticStrength => 'Haptic intensity';

  @override
  String get keypadAppend => 'Append digits after a result';

  @override
  String get keypadClearBeforeNew => 'Clear and start fresh after a result';

  @override
  String get keypadInput => 'Keypad input';

  @override
  String get keypadInputFooter =>
      'Choose what happens when you tap a digit after a bus check result is shown (after ⏎).';

  @override
  String get labelHome => 'Home';

  @override
  String get labelSchool => 'School';

  @override
  String get labelWork => 'Work';

  @override
  String get language => 'Language';

  @override
  String get languageFooter => 'You can change the app display language.';

  @override
  String get languageSystem => 'Use device language';

  @override
  String get lineMap => 'Line map';

  @override
  String get longPressToRegister => 'Long-press to save';

  @override
  String get longPressToRegisterFooter =>
      'Long-press to register the current destination as-is.';

  @override
  String get place => 'Place';

  @override
  String get placeFooter =>
      'Search by station, address, or place name, or long-press the map.';

  @override
  String get placeName => 'Name';

  @override
  String get placeNameFooter =>
      'Name shown in the list. Use something easy to recognize, like Home or Work.';

  @override
  String get placeNamePlaceholder => 'Display name (e.g. Home)';

  @override
  String get planCurrent => 'Current Plan';

  @override
  String get planFree => 'FREE';

  @override
  String get planFreeDescription =>
      'You are on the FREE plan. Upgrade to PREMIUM for unlimited saved places and history.';

  @override
  String planFreeLimitFooter(int count) {
    return 'On the FREE plan, you can save up to $count destinations in history and $count saved places. Upgrade to PREMIUM for unlimited storage.';
  }

  @override
  String get planManagement => 'Plan';

  @override
  String get planNothingToRestore => 'No restorable purchases were found.';

  @override
  String get planPremium => 'PREMIUM';

  @override
  String get planPremiumLimitFooter =>
      'On the PREMIUM plan, history and saved places are unlimited.';

  @override
  String get planRestore => 'Restore Purchases';

  @override
  String get planRestoreFooter =>
      'If you already purchased PREMIUM in the store, restore it here.';

  @override
  String get planRestored => 'Purchases restored.';

  @override
  String get planSwitchDescription =>
      'Debug builds only. Store purchases are not affected.';

  @override
  String get planUpgrade => 'Upgrade to PREMIUM';

  @override
  String get planUpgradeDone => 'Upgrade to PREMIUM completed!';

  @override
  String get preview => 'Preview';

  @override
  String get privacyConsent => 'Consent';

  @override
  String get privacyConsentOff =>
      'Not consented. Route data is not downloaded.';

  @override
  String get privacyConsentOn => 'Consented.';

  @override
  String get privacyDeleteAll => 'Delete All Data';

  @override
  String get privacyDeleteAllConfirm => 'Delete saved data?';

  @override
  String get privacyDeleteAllDetail =>
      'Deletes the destination, destination history, saved places, external-transmission consent, and route data. Purchase status, general preferences, and the route archive are not deleted.';

  @override
  String get privacyFooter => 'Review how data is sent, stored, and deleted.';

  @override
  String get privacyRecipients => 'Recipients, data, and purposes';

  @override
  String get privacyRecipientsBody =>
      '• OpenStreetMap Overpass API (overpass-api.de, Kumi Systems, Mail.ru): your location, search radius, and route IDs, to fetch routes and stops. Sent only with your consent.\n• Map tiles (OpenStreetMap, OSM France): the visible map area, to draw the map.\n• Google Maps (only with an API key and the setting on): the visible map area, to draw the map.\n• Place search (Nominatim, Photon): the text you search and a nearby coordinate to rank results, to find destinations.\n• App Store / Google Play: purchasing and restoring PREMIUM.\nBus checks and the number table are computed on your device only. Nothing is sent to Google.';

  @override
  String get privacyStorage => 'Storage on your device';

  @override
  String get privacyStorageBody =>
      'Route data, its archive, the destination, destination history, saved places, and settings are stored on this device. Route data is also saved to your own iCloud Drive only when iCloud sync is on.';

  @override
  String get privacyTitle => 'Privacy & data';

  @override
  String get routeBoardHint => 'Long-press the number to board or alight';

  @override
  String get routeCandidates => 'Route candidates';

  @override
  String get routeCandidatesHint =>
      'Select a route matching your bus number. Nearest first.';

  @override
  String get routeDataAttribution => 'Route data © OpenStreetMap contributors';

  @override
  String get routeList => 'Route list';

  @override
  String get routeListEmpty => 'No saved routes';

  @override
  String get routeListEmptyDetail =>
      'Download route data in Settings to list them here.';

  @override
  String get routeMapEmpty => 'Enter a bus number to search for routes';

  @override
  String get routeMapErrorTitle => 'Route map error';

  @override
  String get routeMapNoLocation =>
      'Current location is needed to list nearby routes first.';

  @override
  String routeSearchNone(String number) {
    return 'No route matching \"$number\" in the route data on this device.';
  }

  @override
  String get save => 'Save';

  @override
  String get savedPlaces => 'Saved places';

  @override
  String get savedPlacesEmpty => 'No saved places yet';

  @override
  String get savedPlacesEmptyDetail =>
      'Register home or frequent places for one-tap destination setup. Add one with + at the top right.';

  @override
  String get savedPlacesFooter =>
      'Tap to set as destination. Swipe left to delete, tap the pencil to edit.';

  @override
  String savedPlacesFreeLimit(int count) {
    return 'The FREE plan allows only $count saved places.';
  }

  @override
  String get searchFromHistory => 'History';

  @override
  String get searchFromSavedPlaces => 'Saved places';

  @override
  String get showKeypad => 'Show keypad';

  @override
  String get soundBell => 'Bell';

  @override
  String get soundChime => 'Chime';

  @override
  String get soundConfirm => 'Confirm';

  @override
  String get soundDing => 'Ding';

  @override
  String get soundMessage => 'Message';

  @override
  String get soundTiptoes => 'Tiptoes';

  @override
  String get soundTock => 'Tick';

  @override
  String get soundTriTone => 'Tri-tone';

  @override
  String get strengthHeavy => 'Heavy';

  @override
  String get strengthLight => 'Light';

  @override
  String get strengthMedium => 'Medium';

  @override
  String get trackingNotice => 'Tracking your ride for arrival alerts.';

  @override
  String get unlimited => 'Unlimited';

  @override
  String get volume => 'Volume';

  @override
  String get wrongDirectionBody =>
      'This bus may be going the opposite direction. Check the route before boarding.';

  @override
  String get wrongDirectionBodyRouteMap =>
      'This bus may not be heading toward your destination. Get off at the next stop.';

  @override
  String get wrongDirectionTitle => 'Reverse direction?';

  @override
  String get helpIntro =>
      'The app opens on Matrix. Set your destination and pick a bus from the number table. The keypad is under … → Number entry, or swipe right from the left edge.';

  @override
  String get helpBasics => 'Basic operations';

  @override
  String get helpResults => 'Reading results';

  @override
  String get helpRoutes => 'Viewing routes';

  @override
  String get helpTroubleshooting => 'Troubleshooting';

  @override
  String get helpTopTitle => 'Matrix';

  @override
  String get helpTopBody =>
      'This is the screen that opens at launch. It shows destination, current location, distance, and the bus number table. To check a number on the keypad, open … → Number entry. You can also swipe right from the left edge. Return with … → Matrix, or swipe from the left edge again.';

  @override
  String get helpDestinationTitle => 'Set destination';

  @override
  String get helpDestinationBody =>
      'Tap the destination bar to open the map sheet. Search by name or long-press the map, or pick from History or Saved places. Switch between origin and destination at the top of the sheet.';

  @override
  String get helpLocationTitle => 'Location and origin';

  @override
  String get helpLocationBody =>
      'Location permission is requested at launch. Refresh with ↻ in the location bar, or choose an origin on the map with the map icon. Tap × to go back to your current location. While riding, distance is always measured from GPS.';

  @override
  String get helpSavedPlacesTitle => 'Saved places';

  @override
  String get helpSavedPlacesBody =>
      'Open Saved places in the destination sheet to register home and frequent places. Tap one to set it as your destination. Long-press the current destination to save it as-is.';

  @override
  String get helpBusNumberTitle => 'Enter bus number';

  @override
  String get helpBusNumberBody =>
      'Only when a number is missing from the table, open … → Number entry (or swipe from the left edge) and enter digits (e.g. 35). The app matches your trip and can still say board if that bus reaches a transfer stop.';

  @override
  String get helpTableTitle => 'Bus number table';

  @override
  String get helpTableBody =>
      'Bus numbers are grouped by direction and number of transfers. Tap to open the route map, long-press to board or alight. The bus you are riding turns orange.';

  @override
  String get helpBoardTitle => 'Start riding';

  @override
  String get helpBoardBody =>
      'On Number entry, the bus you enter is matched against routes to your destination. If a variant works, a yellow message like \"Get on if it\'s 35A!\" appears; tap Start riding to begin.';

  @override
  String get helpSkipTitle => 'Skip this bus!';

  @override
  String get helpSkipBody =>
      'When no matching variant runs toward your destination, you\'ll see red \"Skip this bus!\".';

  @override
  String get helpDistanceTitle => 'Distance colors';

  @override
  String get helpDistanceBody =>
      'When you are not riding, the badge is the straight-line distance to your destination. While riding, it is the distance to the current bus\'s alighting stop. Blue from 3 km, green from 1 km, yellow from 500 m, orange from 200 m, red under 200 m. Tap the badge while riding to open the route map. Long-press the badge to cancel navigation (this also clears the destination). If you start riding from the line map without a destination, the badge shows \"—\".';

  @override
  String get helpRidingTitle => 'Riding mode';

  @override
  String get helpRidingBody =>
      'Long-press a bus number to start riding. Long-press it again to alight for a transfer. While riding, arrival alerts ring by distance to your stop and tracking continues with the screen off. You are warned if the bus seems to be going the wrong way.';

  @override
  String get helpLineMapTitle => 'Line map';

  @override
  String get helpLineMapBody =>
      '… → Line map finds a route by bus number in the route data on your device and draws it on the map. Use the list button to browse saved routes. Long-press the number badge to board or alight (the last stop is the alighting stop).';

  @override
  String get helpSettingsTitle => 'Settings & alerts';

  @override
  String get helpSettingsBody =>
      'From … → Settings you can change language, keypad input, keypad sound and vibration, arrival alerts, and route data. Arrival alerts are distance-based to the alighting stop, with up to 3 thresholds — alarms play 1–3 times from furthest to closest. When the app is in the background, a notification is shown.';

  @override
  String get helpPlanTitle => 'Plan management';

  @override
  String helpPlanBody(int count) {
    return 'Open … → Plan to view your plan, upgrade to PREMIUM, or restore a previous purchase. FREE plan: up to $count saved places and $count history entries. PREMIUM: unlimited.';
  }

  @override
  String get helpNoRouteTitle => 'No route found';

  @override
  String get helpNoRouteBody =>
      'Make sure you have downloaded route data in Settings and that your location and destination are in the same region. Route data is fetched around your current location.';

  @override
  String get helpNetworkTitle => 'Connection error';

  @override
  String get helpNetworkBody =>
      'Check Wi‑Fi or mobile data, then try again. Bus checks use the route data on your device, so they also work offline.';

  @override
  String get developerScreen => 'Developer';

  @override
  String get devAppInfo => 'App and device';

  @override
  String get devLogs => 'Logs';

  @override
  String get devLogsFooter =>
      'To report a problem, use Send logs to share them by email or another app. Device and app info is added at the top. Locations are rounded to about 100 m.';

  @override
  String get devLogSend => 'Send logs';

  @override
  String devLogSize(int kb, int count) {
    return 'File $kb KB · $count on screen';
  }

  @override
  String get devLogCopy => 'Copy logs';

  @override
  String get devLogCopied => 'Logs copied to the clipboard.';

  @override
  String get devVerboseLog => 'Verbose logging';

  @override
  String get devVerboseLogDetail =>
      'Also records location updates and distance to the stop. Turn on when investigating problems during a ride.';

  @override
  String get devLogClear => 'Clear logs';

  @override
  String get devLogClearConfirm => 'Clear all logs?';

  @override
  String get devTests => 'Tests';

  @override
  String get devTestAlarm => 'Play arrival alarm';

  @override
  String get devTestNotification => 'Show a notification in 5 s';

  @override
  String get devTestNotificationDetail =>
      'Lock the screen after tapping to check background notifications.';

  @override
  String get devRecentLogs => 'Recent logs (newest first)';

  @override
  String get devNoLogs => 'No logs yet';

  @override
  String devTapsLeft(int count) {
    return '$count more taps to open developer screen';
  }

  @override
  String get devLogSubject => 'osmBus log';

  @override
  String get devLogShareText => 'Here is the osmBus log.';

  @override
  String devLogSendFailed(String reason) {
    return 'Could not export logs: $reason';
  }

  @override
  String versionLabel(String version, String build) {
    return 'Version $version ($build)';
  }

  @override
  String get sectionMap => 'Map';

  @override
  String get useGoogleMaps => 'Use Google Maps';

  @override
  String get mapsApiKey => 'Google Maps API key';

  @override
  String mapsKeyUser(String suffix) {
    return 'Set (…$suffix)';
  }

  @override
  String get mapsKeyBundled => 'Using the key built into the app';

  @override
  String get mapsKeyNone => 'Not set';

  @override
  String get mapsKeyRestart => 'Restart the app to apply the change';

  @override
  String get mapsFooter =>
      'With an API key and this switch on, maps are drawn with Google Maps. Otherwise OpenStreetMap is used. Routes and stops always come from the OSM data on your device.';

  @override
  String get mapsFooterAndroid =>
      'On Android the key is built into the app and cannot be changed here.';

  @override
  String get mapsKeyDialogMessage =>
      'Enter a key with Maps SDK for iOS enabled. Save it empty to remove it.';

  @override
  String transferAt(String stop) {
    return 'Transfer: $stop';
  }

  @override
  String get longPressToBoard => 'Long-press to board';

  @override
  String get longPressToGetOff => 'Long-press to get off';
}
