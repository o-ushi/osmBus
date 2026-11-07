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
  String get alightNextStop => 'Get off one stop later';

  @override
  String get alightPreviousStop => 'Get off one stop earlier';

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
  String get keypadSubmit => 'Check';

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
  String get moveToCurrentLocation => 'Move to current location';

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
      'Deletes the destination, destination history, saved places, external-transmission consent, and route data. General preferences and the route archive are not deleted.';

  @override
  String get privacyFooter => 'Review how data is sent, stored, and deleted.';

  @override
  String get privacyRecipients => 'Recipients, data, and purposes';

  @override
  String get privacyRecipientsBody =>
      '• OpenStreetMap Overpass API (overpass-api.de, Kumi Systems, Mail.ru): your location, search radius, and route IDs, to fetch routes and stops. Sent only with your consent.\n• Map tiles (OpenStreetMap, OSM France): the visible map area, to draw the map.\n• Google Maps (only with an API key and the setting on): the visible map area, to draw the map.\n• Place search (Nominatim, Photon): the text you search and a nearby coordinate to rank results, to find destinations.\n• Place search (Apple Maps, on iOS when the query includes Japanese): the text you search, to find a place by its Japanese name. A nearby coordinate is included to prefer closer results.\nBus checks and the number table are computed on your device only. Nothing is sent to Google.';

  @override
  String get privacyStorage => 'Storage on your device';

  @override
  String get privacyStorageBody =>
      'Route data, its archive, the destination, destination history, saved places, corrected stops, and settings are stored on this device. Route data, saved places, destination history, corrected stops, and settings for the number table, arrival alerts, the keypad, and language are also saved to your own iCloud Drive only when iCloud sync is on. Exported backups contain the same.';

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

  @override
  String get routeReviewOpen => 'Check this route';

  @override
  String get stopOrderUsingCustom => 'Using your corrected stops';

  @override
  String get routeReviewTitle => 'Check this route';

  @override
  String get routeReviewOrder => 'Order';

  @override
  String get routeReviewEnds => 'Start and end';

  @override
  String routeReviewEndStart(String stop, int meters) {
    return 'The first stop, $stop, is about $meters m from an end of the line.';
  }

  @override
  String routeReviewEndLast(String stop, int meters) {
    return 'The last stop, $stop, is about $meters m from an end of the line.';
  }

  @override
  String get routeReviewEndsProposal =>
      'The stops closest to the two ends of the line become the first and last stops.';

  @override
  String get routeReviewReset => 'Reset this route\'s corrections';

  @override
  String get routeEditsResetAll => 'Reset all corrected stops';

  @override
  String get routeEditsResetAllConfirm =>
      'Clears corrected stops on this device and returns those routes to the OSM order. If iCloud sync is on, the same corrections are reset on your other devices.';

  @override
  String get routeReviewPlace => 'Location';

  @override
  String get routeReviewMembership => 'Missing or extra stops';

  @override
  String get routeReviewNothing => 'Nothing to point out';

  @override
  String get routeReviewBacktrackIntro =>
      'In the current order, some stops go back 1 km or more along the line.';

  @override
  String routeReviewBetween(String stop, String after, String before) {
    return 'Along the line, $stop is between $after and $before.';
  }

  @override
  String get routeReviewLineStart => 'the start of the line';

  @override
  String get routeReviewLineEnd => 'the end of the line';

  @override
  String get routeReviewPartnerDiffers =>
      'Even allowing for the line direction, the order differs from the return route';

  @override
  String get routeReviewProposal =>
      'Stops within 120 m of the line are put in line order; stops farther away stay where they are.';

  @override
  String get routeReviewUseThis => 'Use this';

  @override
  String routeReviewOffLine(String stop, int meters) {
    return '$stop is about $meters m from this route\'s line.';
  }

  @override
  String routeReviewReplaceCandidate(String ref, int meters) {
    return 'A stop with the same name is on $ref, about $meters m from this line.';
  }

  @override
  String get routeReviewReplace => 'Replace with this stop';

  @override
  String get routeReviewFromPartner =>
      'Stops on the return route that are near this route\'s line but not on this route';

  @override
  String get routeReviewFromOthers =>
      'Stops of other routes that are near this line but not on this route';

  @override
  String get routeReviewOnlyHere => 'Stops only in this direction';

  @override
  String routeReviewCandidate(String stop, String ref, int meters) {
    return '$stop ($ref, about $meters m from the line)';
  }

  @override
  String get routeReviewNoAuto => 'Nothing is added automatically';

  @override
  String get routeReviewEditSelf => 'Edit it yourself';

  @override
  String get routeReviewRevertOsm => 'Back to the OSM order';

  @override
  String get stopOrderUseThis => 'Use this order';

  @override
  String get stopOrderDragHint =>
      'Drag to reorder. Your changes are used only on this device.';

  @override
  String get stopEditAdd => 'Add a stop';

  @override
  String get stopEditPickOnMap => 'Choose a place on the map';

  @override
  String get stopEditPlace => 'Location';

  @override
  String get stopEditDelete => 'Delete';

  @override
  String get stopEditName => 'Stop name';

  @override
  String get stopEditCoordinates => 'Latitude and longitude';

  @override
  String get stopEditLatitude => 'Latitude';

  @override
  String get stopEditLongitude => 'Longitude';

  @override
  String get stopEditLongPressHint => 'Long-press the map to drop a pin.';

  @override
  String get stopEditConfirmPlace => 'Use this place';

  @override
  String get stopEditNoCandidates => 'No nearby stops to add.';

  @override
  String get stopEditAddedByYou => 'Added by you';

  @override
  String get missingNumberEntry => 'A number missing here';

  @override
  String get missingNumberTitle => 'A number missing from this segment';

  @override
  String get missingNumberHint =>
      'Enter the number you expected. A route with a stop near both ends of this segment opens for review.';

  @override
  String get missingNumberField => 'Bus number';

  @override
  String get missingNumberSearch => 'Find';

  @override
  String get missingNumberNone =>
      'That number is not in the routes saved on this device.';

  @override
  String get missingNumberOnSegment => 'Routes with a stop near both ends';

  @override
  String get missingNumberOthers =>
      'The number matches. These routes do not have a stop near both ends of this segment.';

  @override
  String get settingsGroupAlerts => 'Alerts and display';

  @override
  String get settingsGroupRoutes => 'Route data and location';

  @override
  String get settingsGroupBackup => 'Sync and backup';

  @override
  String get helpIntro => 'Set a destination and pick the bus you can take.';

  @override
  String get helpDestTitle => 'Set a destination';

  @override
  String get helpDest1 => 'Tap the destination bar';

  @override
  String get helpDest2 => 'Search for a place or long-press the map';

  @override
  String get helpDest3 => 'You can also use \"Saved places\" or \"History\"';

  @override
  String get helpOriginTitle => 'Change the starting point';

  @override
  String get helpOrigin1 => 'Tap the map icon on the location bar';

  @override
  String get helpOrigin2 => '× returns to your current location';

  @override
  String get helpOrigin3 => '↻ refreshes your location';

  @override
  String get helpPlaceTitle => 'Save a place you often visit';

  @override
  String get helpPlace1 => 'Open \"Saved places\" on the destination sheet';

  @override
  String get helpPlace2 => 'Long-press to save the current destination';

  @override
  String get helpRideTitle => 'Record boarding and getting off';

  @override
  String get helpRide1 => 'Long-press a bus number to board';

  @override
  String get helpRide2 => 'Long-press the same number again to get off';

  @override
  String get helpNumberTitle => 'Check a bus by number';

  @override
  String get helpNumber1 =>
      'Tap \"Number entry\" in … (or swipe right from the left edge)';

  @override
  String get helpNumber2 => 'Enter the digits';

  @override
  String get helpNumber3 => 'If you can board, tap \"Start riding\"';

  @override
  String get helpTableTitle => 'See which buses you can take';

  @override
  String get helpTable1 => 'Set a destination to see the number table';

  @override
  String get helpTable2 => 'Tap a number for its route map';

  @override
  String get helpTable3 => 'The number you are riding is orange';

  @override
  String get helpDistanceTitle => 'Read the distance colors';

  @override
  String get helpDistance1 =>
      'Red, yellow and orange follow the arrival alert distances';

  @override
  String get helpDistance2 => 'Green under 3 km, blue from 3 km';

  @override
  String get helpDistance3 => 'While riding, tap for the current route map';

  @override
  String get helpLineMapTitle => 'See a route map';

  @override
  String get helpLineMap1 => 'Tap \"Line map\" in …';

  @override
  String get helpLineMap2 => 'Search by bus number';

  @override
  String get helpLineMap3 => 'Long-press the number badge to board or get off';

  @override
  String get helpNoRouteTitle => 'When no route is found';

  @override
  String get helpNoRoute1 => 'Download route data in Settings';

  @override
  String get helpNoRoute2 => 'Check both points are in the same area';

  @override
  String get helpMissingTitle => 'When your bus is missing from the table';

  @override
  String get helpMissing1 =>
      'Tap the button for a number missing from this section';

  @override
  String get helpMissing2 => 'Enter the number';

  @override
  String get helpStopTitle => 'When you want to stop navigation';

  @override
  String get helpStop1 => 'Long-press the distance badge';

  @override
  String get helpNetworkTitle => 'When there is a network error';

  @override
  String get helpNetwork1 => 'Check Wi‑Fi or mobile data';

  @override
  String get helpNetwork2 =>
      'Bus checks use data on the device, so they work offline';

  @override
  String get startupStart => 'Get started';

  @override
  String get startupDontShowAgain => 'Don\'t show again';

  @override
  String get startupSetting => 'Startup screen';

  @override
  String get startupSettingNote =>
      'Show the welcome screen when the app launches';
}
