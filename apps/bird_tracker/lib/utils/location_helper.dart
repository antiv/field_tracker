import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:math' as math;

import 'package:bird_tracker/service/data_service.dart';
import 'package:bird_tracker/utils/background_location_permission.dart';
import 'package:bird_tracker/utils/geo_utils.dart';
import 'package:bird_tracker/utils/ux_builder.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

import '../widgets/marker_info.dart';

/// Location service on and foreground permission granted — the one gate every
/// path that starts location updates has to pass. It is deliberately not
/// cached: an "Only this time" grant expires while the app sits in the
/// background, and the user can revoke it in settings at any moment. The
/// `location` plugin used to start updates in `changeSettings` without
/// checking, and Android answered with a SecurityException that no Dart code
/// could catch — that was the top production crash of 1.0.16.
Future<bool> ensureLocationPermission(Location location) async {
  bool serviceEnabled = await location.serviceEnabled();
  if (!serviceEnabled) {
    serviceEnabled = await location.requestService();
    if (!serviceEnabled) return false;
  }

  PermissionStatus status = await location.hasPermission();
  if (status == PermissionStatus.granted) return true;

  if (status == PermissionStatus.denied) {
    if (!await showPermissionInfoDialog()) return false;
    status = await location.requestPermission();
    if (status == PermissionStatus.granted) return true;
  }

  /// "Approximate location" (Android 12+) or the iOS reduced-accuracy
  /// switch: a route recorded with it is worthless. Android offers an
  /// upgrade-to-precise dialog, but only to a request for FINE alone — the
  /// plugin's own `requestPermission` returns at once because coarse already
  /// counts as granted — so that request goes through MainActivity. iOS has
  /// no such prompt; the switch lives in Settings.
  if (status == PermissionStatus.grantedLimited) {
    if (Platform.isAndroid &&
        await BackgroundLocationPermission.requestPrecise()) {
      return true;
    }
    if (await showPreciseLocationDialog()) {
      await BackgroundLocationPermission.openSettings();
    }
    return false;
  }

  if (status == PermissionStatus.deniedForever &&
      await showLocationDeniedForeverDialog()) {
    await BackgroundLocationPermission.openSettings();
  }
  return false;
}

Future<LocationData?> goToCurrentLocation(
    Location location,
    GoogleMapController? controller,
    Completer<GoogleMapController> completer) async {
  if (!await ensureLocationPermission(location)) return null;

  LocationData currentLoc;
  try {
    currentLoc = await location.getLocation().timeout(const Duration(seconds: 5));
  } catch (e) {
    log('Error getting current location: ${e.toString()}');
    return null;
  }
  final target = LatLng(currentLoc.latitude, currentLoc.longitude);
  if (!isFiniteLatLng(target)) return null;

  await goToLocation(target, controller, completer);
  return currentLoc;
}

Future<void> goToLocation(LatLng target, GoogleMapController? controller,
    Completer<GoogleMapController> completer) async {
  if (!isFiniteLatLng(target)) return;
  controller ??= await completer.future;
  try {
    await controller.animateCamera(
        CameraUpdate.newCameraPosition(CameraPosition(target: target, zoom: 16)));
  } on PlatformException catch (e) {
    log('Could not move the camera: ${e.message}');
  }
}

/// Asked at most once per app run: the user who says no should not get the
/// dialog again on every start of a transect.
bool _backgroundPermissionAsked = false;

/// Background updates cost a foreground service with a permanent notification
/// on Android and "Always" authorization on iOS, so they are switched on only
/// for the duration of a recording — [disableBackgroundMode] is its pair.
/// Used to run on every launch and my-location tap, which left the service
/// (and its notification) up with no transect in progress.
Future<bool> enableBackgroundMode(
  Location location,
) async {
  bool bgModeEnabled = await location.isBackgroundModeEnabled();
  if (bgModeEnabled) {
    return true;
  }

  /// The plugin asks for foreground + background location in one request,
  /// which Android 11+ ignores outright — no prompt, no grant. So the
  /// "Allow all the time" step is requested here on its own first; once it is
  /// granted the plugin only has to start its foreground service.
  if (!await ensureBackgroundPermission()) {
    return false;
  }

  try {
    bgModeEnabled = await location.enableBackgroundMode(enable: true);
  } catch (e) {
    log('Error enabling background mode: ${e.toString()}');
    bgModeEnabled = false;
  }
  return bgModeEnabled;
}

Future<void> disableBackgroundMode(Location location) async {
  try {
    if (await location.isBackgroundModeEnabled()) {
      await location.enableBackgroundMode(enable: false);
    }
  } catch (e) {
    log('Error disabling background mode: ${e.toString()}');
  }
}

/// No-op on iOS, where the plugin's own always-authorization flow is correct.
Future<bool> ensureBackgroundPermission() async {
  if (await BackgroundLocationPermission.isGranted()) return true;
  if (_backgroundPermissionAsked) return false;
  _backgroundPermissionAsked = true;

  if (!await showBackgroundPermissionInfoDialog()) return false;
  if (await BackgroundLocationPermission.request()) return true;

  if (await showBackgroundPermissionDeniedDialog()) {
    await BackgroundLocationPermission.openSettings();
  }
  return false;
}

Marker getNewMarker(String id, LocationData locationData, Function onTap) {
  return Marker(
    markerId: MarkerId(id),
    position: LatLng(locationData.latitude, locationData.longitude),
    infoWindow: InfoWindow(title: 'Point $id'),
    icon: BitmapDescriptor.defaultMarker,
    //BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
    onTap: () => onTap(id),
  );
}

void showMarkerInfo(int index) {
  final selected =
      DataService().transect?.markers?.firstWhere((m) => m.id == index);
  showBottomModal(MarkerInfo(selected: selected));
}

double calculateDistance(List<LatLng> polyline) {
  double totalDistance = 0;
  for (int i = 0; i < polyline.length; i++) {
    if (i < polyline.length - 1) {
      // skip the last index
      totalDistance += getStraightLineDistance(
          polyline[i + 1].latitude,
          polyline[i + 1].longitude,
          polyline[i].latitude,
          polyline[i].longitude);
    }
  }
  return totalDistance;
}

double getStraightLineDistance(double lat1, double lon1, double lat2, double lon2) {
  const int R = 6371; // Radius of the earth in km
  final double dLat = deg2rad(lat2 - lat1);
  final double dLon = deg2rad(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(deg2rad(lat1)) *
          math.cos(deg2rad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  final d = R * c; // Distance in km
  return d;
}

double deg2rad(double deg) {
  return deg * (math.pi / 180);
}

String getTimeDifference(DateTime? startDate, DateTime? endDate) {
  if (startDate == null || endDate == null) {
    return '';
  }
  final difference = endDate.difference(startDate);
  return '${difference.inHours}h ${difference.inMinutes.remainder(60)}m';
}

String convertLatLng(double decimal, bool isLat) {
  String degree = "${decimal.toString().split(".")[0]}°";
  double minutesBeforeConversion =
      double.parse("0.${decimal.toString().split(".")[1]}");
  String minutes =
      "${(minutesBeforeConversion * 60).toString().split('.')[0]}'";
  double secondsBeforeConversion = double.parse(
      "0.${(minutesBeforeConversion * 60).toString().split('.')[1]}");
  String seconds =
      '${double.parse((secondsBeforeConversion * 60).toString()).toStringAsFixed(2)}" ';
  String dmsOutput =
      "${isLat ? decimal > 0 ? 'N' : 'S' : decimal > 0 ? 'E' : 'W'} $degree $minutes $seconds";
  return dmsOutput;
}
