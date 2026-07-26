import 'package:geolocator/geolocator.dart';
import 'package:wayfarer_sync_mobile/core/constants/appStrings.dart';

/// Why location is unavailable, so the UI can say something specific and open
/// the settings screen that can actually fix it (R4).
enum LocationAccess { granted, serviceDisabled, denied, deniedForever }

extension LocationAccessCopy on LocationAccess {
  /// Copy lives in AppStrings; the mapping lives here so `core` never has to
  /// know about a feature-level enum.
  String get message {
    switch (this) {
      case LocationAccess.serviceDisabled:
        return AppStrings.locationServicesOff;
      case LocationAccess.deniedForever:
        return AppStrings.locationPermissionBlocked;
      case LocationAccess.denied:
        return AppStrings.locationPermissionDenied;
      case LocationAccess.granted:
        return '';
    }
  }

  String get actionLabel => this == LocationAccess.serviceDisabled
      ? AppStrings.turnOnLocation
      : AppStrings.openSettings;
}

class LocationPermissionHandler {
  /// Re-checks on every call. The user can switch GPS off or revoke permission
  /// at any time, so checking once at first launch is never enough.
  static Future<LocationAccess> check() async {
    // Guarded: this runs from a lifecycle callback, where an unhandled
    // platform exception would leave the user with no explanation at all.
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return LocationAccess.serviceDisabled;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        return LocationAccess.granted;
      }
      if (permission == LocationPermission.deniedForever) {
        return LocationAccess.deniedForever;
      }
      return LocationAccess.denied;
    } catch (_) {
      return LocationAccess.denied;
    }
  }

  /// Opens the screen that can fix [access]: the system location toggle when
  /// the service is off, this app's settings page when permission is blocked.
  static Future<void> openSettingsFor(LocationAccess access) async {
    try {
      await (access == LocationAccess.serviceDisabled
          ? Geolocator.openLocationSettings()
          : Geolocator.openAppSettings());
    } catch (_) {
      // Nothing useful to say if the OS refuses to open its own settings.
    }
  }
}
