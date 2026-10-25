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
}
