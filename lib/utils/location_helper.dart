import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;

import 'package:herp_tracker/service/data_service.dart';
import 'package:herp_tracker/utils/background_location_permission.dart';
import 'package:herp_tracker/utils/ux_builder.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

import '../widgets/marker_info.dart';

Future<LocationData?> goToCurrentLocation(
    bool serviceEnabled,
    Location location,
    LocationData? locationData,
    GoogleMapController? controller,
    Completer<GoogleMapController> completer) async {
  serviceEnabled = await location.serviceEnabled();
  if (!serviceEnabled) {
    serviceEnabled = await location.requestService();
    if (!serviceEnabled) {
      return null;
    }
  }

  PermissionStatus permissionGranted = await location.hasPermission();
  if (permissionGranted == PermissionStatus.denied) {
    bool ok = await showPermissionInfoDialog();
    if (!ok) return null;

    permissionGranted = await location.requestPermission();
    if (permissionGranted != PermissionStatus.granted) {
      return null;
    }
  }

  LocationData currentLoc;
  try {
    currentLoc = await location.getLocation().timeout(const Duration(seconds: 5));
  } catch (e) {
    log('Error getting current location: ${e.toString()}');
    return null;
  }
  if (currentLoc.latitude == null || currentLoc.longitude == null) {
    return null;
  }

  // specified current users location
  CameraPosition cameraPosition = CameraPosition(
    target: LatLng(currentLoc.latitude!, currentLoc.longitude!),
    zoom: 16,
  );
  await enableBackgroundMode(location);

  /// if controller is not initialized, wait for it
  // if (!_controller.isCompleted) {
  //   controller = await _controller.future;
  // }
  controller ??= await completer.future;
  controller.animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
  // });
  return currentLoc;
}

Future<void> goToLocation(
    LatLng locationData, GoogleMapController? controller, Completer<GoogleMapController> completer) async {
  CameraPosition cameraPosition = CameraPosition(
    target: locationData,
    zoom: 16,
  );
  controller ??= await completer.future;
  controller.animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
}

/// Asked at most once per app run: the user who says no should not get the
/// dialog again on every tap of the my-location button.
bool _backgroundPermissionAsked = false;

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
    position: LatLng(locationData.latitude!, locationData.longitude!),
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
