/// Behavioral/configuration constants: durations, storage keys, map defaults,
/// tracking thresholds. Copy lives in [AppStrings]; endpoints live in `ApiUrl`.
class AppConstants {
  AppConstants._();

  // --- Persistence keys (SharedPreferences) ---
  static const String jwtTokenKey = 'jwt_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String currentUserKey = 'current_user';
  static const String themeModeKey = 'theme_mode';

  // --- Network ---
  /// Ceiling for a single HTTP request before it is treated as a timeout.
  static const Duration requestTimeout = Duration(seconds: 20);

  /// Sentinel status code for failures that never reached the server
  /// (no connection, timeout, DNS lookup failed).
  static const int noResponseStatus = 0;

  /// Sent as `X-Client-Version` so the server can measure adoption. Must stay
  /// in sync with `version:` in pubspec.yaml.
  static const String clientVersion = '1.0.5';

  /// Refresh pre-emptively once the access token is this close to expiring,
  /// so ordinary requests never see a 401 in the first place.
  static const Duration proactiveRefreshWindow = Duration(minutes: 3);

  /// How often an open socket re-authenticates. Deliberately shorter than the
  /// server's own auth window so one missed cycle — a brief tunnel — does not
  /// close the connection.
  static const Duration wsReauthInterval = Duration(minutes: 10);

  /// Server close code meaning "your socket auth expired". Wire protocol
  /// shared with `backend/src/websocket.ts`; do not change independently.
  static const int wsAuthExpiredCloseCode = 4001;

  // --- Durations & animations ---
  static const Duration searchDebounce = Duration(milliseconds: 500);
  static const Duration osrmRequestTimeout = Duration(seconds: 8);
  static const Duration snackBarShort = Duration(seconds: 1);
  static const Duration snackBarNormal = Duration(seconds: 2);
  static const Duration buttonPressAnimation = Duration(milliseconds: 90);
  static const Duration skeletonShimmerDuration = Duration(milliseconds: 1100);

  // --- Map defaults ---
  static const double createTripInitialZoom = 5.0;
  static const double mapInitialZoom = 13.0;
  static const double mapMinZoom = 2.0;
  static const double mapMaxZoom = 18.0;
  static const double mapZoomStep = 1.0;

  /// Zoom level applied when centering the map on a specific member.
  static const double mapFocusZoom = 15.0;
  static const String osmTileUrlTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  // --- Live tracking ---
  /// Minimum movement (meters) before a new location update is emitted.
  static const int locationDistanceFilterMeters = 10;

  /// Cap on retained GPS trail points per member to bound memory.
  static const int maxTrailPoints = 500;

  /// Trail split threshold (meters) between consecutive points: a jump this large
  /// is a teleport (stale/out-of-order fix), not real movement — don't draw it.
  static const double maxTrailSegmentMeters = 1000;

  // --- Trip overflow-menu action ids ---
  static const String menuActionShare = 'share';
  static const String menuActionEnd = 'end';

  // --- External geo services ---
  /// Fallback hex color for a member whose server record has no color set.
  static const String defaultMemberColorHex = '#FF5722';

  static const int nominatimSearchLimit = 5;
  static const String nominatimBaseUrl = 'https://nominatim.openstreetmap.org';
  static const String osrmDrivingBaseUrl =
      'https://router.project-osrm.org/route/v1/driving/';
}
