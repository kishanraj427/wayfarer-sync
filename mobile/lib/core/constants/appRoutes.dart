/// Central home for in-app navigation route paths (GoRouter).
///
/// These are client-side navigation locations, distinct from backend API
/// endpoints (which live in `ApiUrl`). Static fields are fixed locations;
/// [tripMap] builds the concrete path for the parameterized trip-map route
/// whose GoRoute pattern is [tripMapPattern].
class AppRoutes {
  AppRoutes._();

  static const String login = '/login';
  static const String signup = '/signup';
  static const String trips = '/trips';
  static const String profile = '/profile';
  static const String createTrip = '/create-trip';

  /// GoRoute path pattern for the live trip map (with `:tripId` / `:userId`).
  static const String tripMapPattern = '/trip/:tripId/map/:userId';

  /// Concrete navigation path to a member's live view of a trip map.
  static String tripMap({required String tripId, required String userId}) =>
      '/trip/$tripId/map/$userId';
}
