import 'dart:async';
import 'dart:developer';
import 'package:tracker_core/config/tracker_config.dart';
import 'package:tracker_core/model/point.dart';
import 'package:tracker_core/model/transect.dart';
import 'package:tracker_core/service/data_service.dart';
import 'package:tracker_core/service/sembast_service.dart';
import 'package:tracker_core/utils/geo_utils.dart';
import 'package:tracker_core/utils/location_helper.dart';
import 'package:tracker_core/utils/ux_builder.dart';
import 'package:tracker_core/widgets/app_menu.dart';
import 'package:tracker_core/widgets/record_form_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

import 'model/placemark.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _key = GlobalKey();

  Location location = Location();
  Transect? transect = DataService().transect;

  LocationData? _locationData;

  /// The camera follows the user only while the map is actually on screen.
  /// Updates keep arriving from the foreground service with the screen off,
  /// and animating a paused, surface-less MapView every second is what fed
  /// the renderer NaN targets — "NaN is not a valid value: (NaN,NaN)", the
  /// other production crash of 1.0.16. Points are still recorded regardless.
  bool _appVisible = true;

  /// Last position the camera was sent to: with distanceFilter 0 a fix comes
  /// every second even standing still, and re-animating to the same spot is
  /// pure churn.
  LatLng? _lastCameraTarget;

  StreamSubscription<LocationData>? locationStream;

  final Completer<GoogleMapController> _completer = Completer();
  GoogleMapController? controller;
  Set<Marker> _markers = {};
  // on below line we have specified camera position
  static const CameraPosition _kHome = CameraPosition(
    target: LatLng(44.8, 20.36),
    zoom: 14.4746,
  );

  late final Set<Polyline>? _polyLines;

  @override
  void initState() {
    SembastService().init();
    _polyLines = {
      Polyline(
        polylineId: const PolylineId('1'),
        points:
            transect?.points
                ?.map((e) => LatLng(e.latitude, e.longitude))
                .toList() ??
            [],
        color: Colors.red,
        width: 5,
      ),
    };

    DataService().initPreferences();
    DataService().completer = _completer;
    DataService().controller = controller;
    WidgetsBinding.instance.addObserver(this);

    /// one dialog at a time: the permission flow first, the resume question
    /// after it — shown together, "Continue" could be tapped with the
    /// permission prompt still open, and two permission requests in flight
    super.initState();
    _goToCurrentLocation().whenComplete(_checkOpenTransect);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final visible = state == AppLifecycleState.resumed;
    if (visible == _appVisible) return;
    _appVisible = visible;
    if (!visible || !mounted) return;

    /// back on screen: draw what was recorded meanwhile and catch the
    /// camera up with the user in one move
    setState(() {});
    final loc = _locationData;
    if (loc != null && locationStream != null) {
      _followCamera(LatLng(loc.latitude, loc.longitude));
    }
  }

  /// A transect is "open" while its endDate is null. Only one may exist:
  /// on startup, stale open transects (left behind by kills/crashes or the
  /// old multi-active bug) are closed, and for the most recent one the user
  /// decides whether to continue or finish it — silently resuming could draw
  /// a false straight line if the user is now somewhere else entirely.
  Future<void> _checkOpenTransect() async {
    await SembastService().init();
    final openTransects = await SembastService().getOpenTransects();
    if (openTransects.isEmpty) return;

    for (final stale in openTransects.skip(1)) {
      _closeTransect(stale);
    }

    final open = openTransects.first;
    showYesNoDialog(
      () async {
        /// both, and in this order: the state's copy is what Stop, Pause and
        /// the marker paths read, and waiting for the Consumer to sync it on
        /// the next frame leaves them looking at a null transect while
        /// _startListener is still awaiting the permission flow
        transect = open;
        DataService().setTransect(open);

        /// the user confirmed they are resuming this transect — start
        /// recording right away so the track continues from its last point;
        /// setTransect moved the camera to the transect start (goToFirst),
        /// so bring it back to where the user actually is. Without the
        /// permission the transect simply stays open for the next attempt.
        if (await _startListener()) {
          await _goToCurrentLocation();
          showSnackBar('transect_resumed'.tr());
        }
        if (mounted) setState(() {});
      },
      () {
        _closeTransect(open);
      },
      title: 'unfinished_transect'.tr(
        args: [DateFormat('dd.MM.yyyy HH:mm').format(open.startDate)],
      ),
      yesText: 'continue'.tr(),
      noText: 'finish'.tr(),
    );
  }

  /// Route points carry no timestamps, so the last marker time (or the
  /// start) is the best available estimate for when recording ended.
  void _closeTransect(Transect transect) {
    final markers = transect.markers;
    transect.endDate =
        (markers != null && markers.isNotEmpty
            ? markers.last.endDate ?? markers.last.startDate
            : null) ??
        transect.startDate;
    SembastService().updateTransect(transect);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// The my-location button and the startup centering. A running recording
  /// is left alone — `getLocation` works alongside the stream, and stopping
  /// and restarting it here used to bounce the foreground service too.
  Future<void> _goToCurrentLocation() async {
    final loc = await goToCurrentLocation(location, controller, _completer);
    if (loc != null && mounted) {
      setState(() {
        _locationData = loc;
      });
    }
    if (locationStream == null) return;
    try {
      for (final mark in _markers) {
        await controller?.hideMarkerInfoWindow(mark.markerId);
      }
      if (_markers.isNotEmpty) {
        await controller?.showMarkerInfoWindow(_markers.last.markerId);
      }
    } on PlatformException catch (e) {
      log('Could not toggle the marker info window: ${e.message}');
    }
  }

  void onLocationChange(LocationData currentLocation) {
    log(
      'Location updated in listener: lat=${currentLocation.latitude}, lng=${currentLocation.longitude}',
    );
    final target = LatLng(currentLocation.latitude, currentLocation.longitude);
    if (!isFiniteLatLng(target)) return;

    /// the record is kept whether or not anyone is looking
    _locationData = currentLocation;
    _polyLines?.first.points.add(target);
    transect?.points = transect?.points?.toList(growable: true) ?? [];
    transect?.points?.add(
      Point()
        ..latitude = target.latitude
        ..longitude = target.longitude,
    );

    if (!_appVisible || !mounted) return;
    setState(() {});
    _followCamera(target);
  }

  /// Pans to [target] at the current zoom, skipping anything the renderer
  /// would choke on — a non-finite zoom or target — and a target it is
  /// already at.
  Future<void> _followCamera(LatLng target) async {
    final map = controller;
    if (map == null || !isFiniteLatLng(target) || target == _lastCameraTarget) {
      return;
    }
    try {
      final zoom = await map.getZoomLevel();
      if (!zoom.isFinite || !_appVisible || !mounted) return;
      await map.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: target, zoom: zoom),
        ),
      );

      /// recorded only once the move went out: a follow that bailed above
      /// must not make the resume catch-up think the camera is already there
      _lastCameraTarget = target;
    } on PlatformException catch (e) {
      /// the map is not ready, or is being torn down — nothing to follow
      log('Could not follow the camera: ${e.message}');
    }
  }

  /// Starts recording. `false` when it could not: no service, no permission.
  /// The permission gate is not optional — `changeSettings` starts updates
  /// natively, and without the grant that used to kill the process.
  ///
  /// The subscription is only assigned after several awaits (permission
  /// dialogs, the foreground service), so a second call in that window
  /// joins the one in flight instead of subscribing a second time — the
  /// first subscription would be overwritten and never cancelled, and keep
  /// recording after Stop.
  Future<bool> _startListener() =>
      _listenerStarting ??= _doStartListener().whenComplete(() {
        _listenerStarting = null;
      });

  Future<bool>? _listenerStarting;

  Future<bool> _doStartListener() async {
    if (locationStream != null) return true;
    if (!await ensureLocationPermission(location)) {
      showSnackBar('location_permission_required'.tr());
      return false;
    }
    try {
      await location.changeSettings(
        accuracy: LocationAccuracy.high,
        interval: 1000,
        distanceFilter: 0,
      );
    } catch (e) {
      log('Could not apply location settings: $e');
    }
    DataService().isOpen.value = false;
    _lastCameraTarget = null;

    /// "Allow all the time" is asked for here, at the moment it is needed;
    /// declined, the route is still recorded while the app is on screen
    await enableBackgroundMode(location);

    locationStream = location.onLocationChanged.listen(
      onLocationChange,
      onError: (Object e) => log('Location stream error: $e'),
    );

    log('Fetching initial location for startListener...');
    location
        .getLocation()
        .timeout(const Duration(seconds: 4))
        .then((initialLocation) {
          log(
            'initialLocation fetched for startListener: lat=${initialLocation.latitude}, lng=${initialLocation.longitude}',
          );
          if (mounted) {
            setState(() {
              _locationData = initialLocation;
            });
          }
        })
        .catchError((e) {
          log('Error getting initial location on startListener: $e');
        });
    return true;
  }

  Future<void> _pauseListener() async {
    /// The recording can outlive its transect — "clear map", a Stop already
    /// taken, or a Start still waiting on the permission dialog — so there
    /// may be nothing left to save. Stopping the stream is the part that
    /// always has to happen.
    final active = transect;
    if (active == null) {
      await _stopListener();
      return;
    }
    active.points = _recordedPoints();
    await SembastService().updateTransect(active);
    _stopListener();
  }

  /// The track as the map has it — every fix was added to the polyline, so
  /// it is the record of where the user walked.
  List<Point> _recordedPoints() =>
      _polyLines?.first.points
          .map(
            (e) => Point()
              ..latitude = e.latitude
              ..longitude = e.longitude,
          )
          .toList() ??
      [];

  /// Every end of a recording — pause, stop, clear — goes through here, so
  /// this is where the foreground service and its notification go away.
  Future<void> _stopListener() async {
    locationStream?.cancel();
    locationStream = null;
    await disableBackgroundMode(location);
  }

  Future<void> _stopTransect() async {
    /// Nothing to name: a second Stop on the still-open dial, or a Start
    /// that has not created the row yet — on a simulator the permission and
    /// location calls take seconds, so that window is wide. Just make sure
    /// the recording is off.
    if (transect == null) {
      await _stopListener();
      if (mounted) setState(() {});
      return;
    }

    final hasPoints =
        transect?.markers != null && transect!.markers!.isNotEmpty;
    if (!hasPoints) {
      showYesNoDialog(
        () {
          _promptSaveTransect();
        },
        () {
          showYesNoDialog(
            () async {
              await _deleteActiveTransect();
            },
            () {},
            title: 'delete_transect_confirm'.tr(),
            yesText: 'delete'.tr(),
            noText: 'cancel'.tr(),
          );
        },
        title: 'no_points_save_prompt'.tr(),
        yesText: 'save'.tr(),
        noText: 'no'.tr(),
      );
      return;
    }

    _promptSaveTransect();
  }

  void _promptSaveTransect() {
    /// showTextInputDialog to enter transect name
    showTextInputDialog(
      'enter_transect_name'.tr(),
      'transect_name'.tr(),
      'Transect ${DateFormat('dd.MM.yyyy').format(DateTime.now())}',
      (name) async {
        await _stopListener();

        /// read again rather than captured above: the dialog stayed open for
        /// as long as the user took to type, and "clear map" or another Stop
        /// could have finished the transect in the meantime
        final active = transect;
        if (active == null) {
          if (mounted) setState(() {});
          return;
        }
        active.endDate = DateTime.now();
        active.name = name;
        active.points = _recordedPoints();

        /// close last marker if not closed
        final markers = active.markers;
        if (markers != null && markers.isNotEmpty) {
          markers.last.endDate ??= DateTime.now();
        }
        await SembastService().updateTransect(active);
        transect = null;
        DataService().setTransect(null);
        if (mounted) setState(() {});
      },
    );
  }

  Future<void> _deleteActiveTransect() async {
    await _stopListener();
    final active = transect;
    if (active != null) {
      await SembastService().deleteTransect(active);
    }
    transect = null;
    DataService().setTransect(null);
    showSnackBar('transect_deleted'.tr());
    if (mounted) setState(() {});
  }

  void _addMarker() async {
    DataService().isOpen.value = false;
    setState(() {});

    if (_locationData == null) {
      showSnackBar('getting_current_location'.tr());
      try {
        log('Attempting to fetch location via getLocation() with timeout...');
        _locationData = await location.getLocation().timeout(
          const Duration(seconds: 4),
        );
        log(
          'getLocation() returned: lat=${_locationData?.latitude}, lng=${_locationData?.longitude}',
        );
      } catch (e) {
        log('Error getting location: ${e.toString()}');
      }
    }

    final current = _locationData;
    if (current == null ||
        !isFiniteLatLng(LatLng(current.latitude, current.longitude))) {
      showSnackBar('location_not_available'.tr());
      return;
    }

    int radius = DataService().getPointRadiusPreference();
    Placemark? closestMarker;
    double minDistanceMeters = double.infinity;

    for (var marker in transect?.markers ?? <Placemark>[]) {
      double distKm = getStraightLineDistance(
        marker.latitude ?? 0,
        marker.longitude ?? 0,
        current.latitude,
        current.longitude,
      );
      double distM = distKm * 1000;
      if (distM < radius && distM < minDistanceMeters) {
        minDistanceMeters = distM;
        closestMarker = marker;
      }
    }

    if (closestMarker != null) {
      showAlertDialog(
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'point_nearby_title'.tr(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text('point_nearby_content'.tr(args: [radius.toString()])),
            ],
          ),
        ),
        [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _createNewMarker();
                  },
                  child: FittedBox(child: Text('create_new'.tr())),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _addToExistingMarker(closestMarker!);
                  },
                  child: FittedBox(child: Text('add_to_existing'.tr())),
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      _createNewMarker();
    }
  }

  void _addToExistingMarker(Placemark marker) {
    showFullScreenDialog(
      RecordFormShell(
        onSaved: (record, close) {
          setState(() {
            marker.records?.add(record);
          });
          _goToCurrentLocation();
          _saveTransect();
        },
      ),
    );
  }

  /// Persist the active transect, if there still is one — a record is saved
  /// long after its form opened, and the transect may have been finished or
  /// cleared while the surveyor was filling it in.
  void _saveTransect() {
    final active = transect;
    if (active == null) {
      log('Record saved with no active transect — nothing to update');
      return;
    }
    SembastService().updateTransect(active);
  }

  void _createNewMarker() {
    /// close last marker
    final previous = transect?.markers;
    if (previous != null && previous.isNotEmpty) {
      previous.last.endDate ??= DateTime.now();
    }

    final double? markerLatitude = _locationData?.latitude;
    final double? markerLongitude = _locationData?.longitude;
    final double? markerAltitude = _locationData?.altitude;
    final double? markerAccuracy = _locationData?.accuracy;

    if (markerLatitude == null || markerLongitude == null) {
      showSnackBar('location_not_available'.tr());
      return;
    }

    showFullScreenDialog(
      RecordFormShell(
        onSaved: (record, close) {
          setState(() {
            transect?.markers = transect?.markers?.toList(growable: true) ?? [];
            transect?.markers?.add(
              Placemark(
                latitude: markerLatitude,
                longitude: markerLongitude,
                altitude: markerAltitude,
                accuracy: markerAccuracy,
                startDate: DateTime.now(),
                endDate: null,
                id: transect?.markers?.length ?? 0,
                records: [record],
              ),
            );
          });
          _goToCurrentLocation();
          _saveTransect();
        },
      ),
    );
  }

  /// A quick second tap on the Start button lands while the first one is
  /// still waiting on the permission dialog; it must not open a second
  /// transect row.
  Future<void> _startTransect() =>
      _transectStarting ??= _doStartTransect().whenComplete(() {
        _transectStarting = null;
      });

  Future<void>? _transectStarting;

  Future<void> _doStartTransect() async {
    /// only one transect may be active — an open one is always resumed,
    /// never replaced; a new one requires closing the old one via Stop
    if (transect != null && transect!.endDate == null) {
      if (await _startListener()) showSnackBar('transect_resumed'.tr());
    } else {
      /// in-memory transect is null (or a closed one viewed from history);
      /// the DB may still hold an open transect — resume it instead of
      /// creating a second one
      final openTransects = await SembastService().getOpenTransects();
      if (openTransects.isNotEmpty) {
        transect = openTransects.first;
        DataService().setTransect(transect);
        if (await _startListener()) showSnackBar('transect_resumed'.tr());
      } else {
        await _startNewTransect();
      }
    }
    if (mounted) setState(() {});
  }

  /// Permission first, row second: a transect that never recorded a point
  /// would otherwise sit open in the database and be offered for resume on
  /// every launch.
  Future<void> _startNewTransect() async {
    if (!await ensureLocationPermission(location)) {
      showSnackBar('location_permission_required'.tr());
      return;
    }
    final started = Transect()
      ..startDate = DateTime.now()
      ..points = List<Point>.empty(growable: true)
      ..markers = List<Placemark>.empty(growable: true);
    transect = started;
    DataService().setTransect(started);

    /// insert transect to db
    SembastService().addTransect(started);
    await _startListener();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _key,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F9D58),
        title: Text(
          TrackerConfig.current.appTitle,
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<Locale>(
              value: context.locale,
              icon: const SizedBox(
                width: 20,
              ), //const Icon(Icons.arrow_drop_down, color: Colors.white),
              dropdownColor: const Color(0xFF0F9D58),
              onChanged: (Locale? newLocale) {
                if (newLocale != null) {
                  context.setLocale(newLocale);
                  setState(() {});
                }
              },
              items: const [
                DropdownMenuItem(
                  value: Locale('en'),
                  child: Text('🇬🇧 EN', style: TextStyle(color: Colors.white)),
                ),
                DropdownMenuItem(
                  value: Locale('sr', 'Latn'),
                  child: Text('🇷🇸 SR', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ],
        leading: InkWell(
          onTap: () {
            _key.currentState!.openDrawer();
          },
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: SvgPicture.asset(
              TrackerConfig.current.logoAsset,
              fit: BoxFit.scaleDown,
              semanticsLabel: '${TrackerConfig.current.appTitle} Logo',
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ),
      drawer: const Drawer(child: AppMenu()),
      body: SafeArea(
        // on below line creating google maps
        child: Consumer<DataService>(
          builder: (context, dataService, _) {
            transect = dataService.transect;

            /// transect was cleared externally (e.g. "clear map") while
            /// recording — stop the location listener too
            if (transect == null && locationStream != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                await _stopListener();
                if (mounted) setState(() {});
              });
            }
            _polyLines?.first.points.clear();
            _polyLines?.first.points.addAll(
              transect?.points
                      ?.map((e) => e.latLng)
                      .where(isFiniteLatLng)
                      .toList() ??
                  [],
            );
            _markers = Set<Marker>.of(
              transect?.markers
                      ?.where((e) => e.hasFiniteLatLng)
                      .map((e) => e.toMarker()) ??
                  [],
            );
            return GoogleMap(
              key: const Key('map'),
              // on below line setting camera position
              initialCameraPosition: _kHome,
              // on below line we are setting markers on the map
              markers: _markers,
              polylines: _polyLines ?? {},
              // on below line specifying map type.
              mapType: dataService.mapType ?? MapType.hybrid,
              // on below line setting user location enabled.
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              // on below line setting compass enabled.
              compassEnabled: true,
              // on below line setting zoom controls enabled.
              zoomControlsEnabled: true,
              // on below line setting map toolbar enabled.
              mapToolbarEnabled: true,
              // on below line setting traffic enabled
              trafficEnabled: false,
              // on below line setting buildings enabled.
              buildingsEnabled: false,
              indoorViewEnabled: false,
              // on below line specifying controller on map complete.
              onMapCreated: (GoogleMapController mapController) {
                controller = mapController;
                _completer.complete(mapController);
                DataService().controller = mapController;
              },
            );
          },
        ),
      ),
      // on pressing floating action button the camera will take to user current location
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          /// Calculate position somehow
          top:
              (Theme.of(context).appBarTheme.toolbarHeight ?? 56) +
              150 +
              (DataService().isOpen.value ? 130 : 10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            FloatingActionButton(
              onPressed: _goToCurrentLocation,
              backgroundColor: Colors.grey.shade400,
              foregroundColor: Colors.white,
              child: const Icon(Icons.location_searching),
            ),
            const SizedBox(height: 10),
            SpeedDial(
              openCloseDial: DataService().isOpen,
              icon: Icons.directions_walk,
              backgroundColor: locationStream != null
                  ? Colors.red.shade700
                  : Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              activeIcon: Icons.close,
              activeForegroundColor: Colors.white,
              spacing: 3,
              mini: false,
              childPadding: const EdgeInsets.all(5),
              spaceBetweenChildren: 4,
              direction: SpeedDialDirection.down,
              renderOverlay: false,
              onOpen: () {
                setState(() {
                  if (locationStream == null) {
                    DataService().isOpen.value = false;
                    _startTransect();
                  }
                });
              },
              onClose: () {
                setState(() {});
              },

              /// Pause and Stop exist only while something is recording: the
              /// dial doubles as the Start button, and a tap on it flashed
              /// them for a frame or two before onOpen closed it again —
              /// long enough to hit Stop before the transect existed.
              children: locationStream == null
                  ? const []
                  : [
                      SpeedDialChild(
                        child: const Icon(Icons.pause),
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                        label: 'pause'.tr(),
                        onTap: () async {
                          await _pauseListener();
                          setState(() {});
                        },
                      ),
                      SpeedDialChild(
                        child: const Icon(Icons.stop),
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                        label: 'stop'.tr(),
                        onTap: () async {
                          await _stopTransect();
                        },
                      ),
                    ],
            ),
            SizedBox(height: DataService().isOpen.value ? 130 : 10),
            FloatingActionButton(
              onPressed: locationStream != null
                  ? _addMarker
                  : () => showSnackBar('start_transect_first'.tr()),
              backgroundColor: Colors.orangeAccent,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add_location_alt_outlined),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
    );
  }
}
