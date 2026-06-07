import 'package:geolocator/geolocator.dart';

class LocationPermissionHandler {
  /// Asserts that system-level location services are turned on and permitted by the user
  static Future<bool> requestPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if device GPS toggle is turned on
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    
    if (permission == LocationPermission.deniedForever) return false;

    return true;
  }
}