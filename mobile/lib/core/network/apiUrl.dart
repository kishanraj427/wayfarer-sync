class ApiUrl {
  static const String baseUrl = 'http://192.168.1.7:3000/api';
  static const String wsBaseUrl = 'ws://192.168.1.7:3000';

  static const String login = '/auth/login';
  static const String signup = '/auth/signup';
  static const String trips = '/trip';

  static String joinTrip(String tripId) => '/trip/$tripId/join';
  static String tripDetails(String tripId) => '/trip/$tripId';
  static String tripMembers(String tripId) => '/trip/$tripId/members';
  static String uploadBatch(String tripId) => '/trip/$tripId/paths/batch';
}
