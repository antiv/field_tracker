import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../model/transect.dart';

/// Singleton data service class to hold data for the app
class DataService with ChangeNotifier {
  static final DataService _singleton = DataService._internal();

  factory DataService() {
    return _singleton;
  }

  SharedPreferences? prefs;

  Future<void> initPreferences() async {
    prefs = await SharedPreferences.getInstance();
  }

  void setEmailPreference(String email) {
    prefs?.setString('email', email);
  }

  /// Free-form app preferences — an app keeps its own keys here (the last
  /// locality, the surveyor's name) without the shared service knowing them.
  void setString(String key, String value) {
    prefs?.setString(key, value);
  }

  String? getString(String key) => prefs?.getString(key);

  void setPointRadiusPreference(int radius) {
    prefs?.setInt('point_radius', radius);
  }

  int getPointRadiusPreference() {
    return prefs?.getInt('point_radius') ?? 10;
  }

  DataService._internal();

  Transect? transect;

  MapType? mapType;

  ValueNotifier<bool> isOpen = ValueNotifier<bool>(false);

  Completer<GoogleMapController> completer = Completer();
  GoogleMapController? controller;

  void setMapType(MapType? mapType) {
    this.mapType = mapType;
    notifyListeners();
  }

  /// Notify listeners
  void notify() {
    notifyListeners();
  }

  void setTransect(Transect? transect) {
    this.transect = transect;
    this.transect?.goToFirst();
    notifyListeners();
  }

  void clearTransect() {
    transect = null;
    notifyListeners();
  }

  String? getEmailPreference() {
    return prefs?.getString('email');
  }
}
