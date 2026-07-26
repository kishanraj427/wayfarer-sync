/// Central home for all user-facing copy in the app.
///
/// Static const fields hold fixed strings; static methods build the few
/// strings that interpolate runtime values. Behavioral / config constants
/// live in [AppConstants]; backend endpoints live in `ApiUrl`.
class AppStrings {
  AppStrings._();

  // --- App ---
  static const String appName = 'Wire';
  static const String liveTripFallback = 'Live trip';

  // --- Auth: login ---
  static const String loginTagline = 'Find your people on the map.';
  static const String emailLabel = 'Email address';
  static const String passwordLabel = 'Password';
  static const String loginButton = 'Log in';
  static const String noAccountPrompt = "Don't have an account? Sign up";
  static const String emptyCredentials =
      'Email and password fields cannot be empty.';

  // --- Auth: signup ---
  static const String createAccountTitle = 'Create your account';
  static const String signupTagline = 'Start a trip and bring your people along.';
  static const String firstNameLabel = 'First name';
  static const String lastNameLabel = 'Last name';
  static const String confirmPasswordLabel = 'Confirm password';
  static const String signupButton = 'Sign up';
  static const String haveAccountPrompt = 'Already have an account? Log in';
  static const String allFieldsRequired = 'All fields are required.';
  static const String passwordsDontMatch = "Passwords don't match.";

  // --- Auth: password field ---
  static const String showPassword = 'Show password';
  static const String hidePassword = 'Hide password';

  // --- Network / API errors ---
  static const String networkError =
      "Can't reach the server. Check your internet connection and try again.";
  static const String timeoutError =
      'The server took too long to respond. Please try again.';
  static const String serverError =
      'Something went wrong on our end. Please try again in a moment.';
  static const String unknownError =
      'An unexpected error occurred. Please try again.';

  // --- Auth session (R4) ---
  static const String sessionExpiredBanner =
      "You've been signed out. Please sign in again.";
  static const String invalidCredentials = 'Incorrect email or password.';
  static const String rateLimitedError =
      'Too many attempts. Please try again in a few minutes.';
  static const String offlineStillRecording =
      "You're offline. Your trip is still being recorded and will sync automatically.";
  static const String reconnectingLiveTracking = 'Reconnecting live tracking…';

  // --- Request failures, by outcome ---
  static const String invalidRequest =
      'Please check the details you entered and try again.';
  static const String noAccess = "You don't have access to this.";
  static const String notFound =
      "We couldn't find that. It may have been deleted.";
  static const String alreadyExists =
      'An account with this email already exists. Try signing in instead.';

  /// The single place an HTTP status becomes something a person can read.
  ///
  /// The server's own `error` text is developer-facing ("tripId must be a
  /// valid UUID", "Not authenticated") and must never reach the screen (R4).
  static String messageForStatus(int statusCode) {
    switch (statusCode) {
      case 0:
        return networkError;
      case 400:
      case 422:
        return invalidRequest;
      case 401:
      case 403:
        return noAccess;
      case 404:
        return notFound;
      case 409:
        return alreadyExists;
      case 429:
        return rateLimitedError;
      default:
        return statusCode >= 500 ? serverError : unknownError;
    }
  }

  // --- Navigation ---
  static const String navTrips = 'Trips';
  static const String navProfile = 'Profile';

  // --- Common actions & dialogs ---
  static const String cancel = 'Cancel';
  static const String share = 'Share';
  static const String endTrip = 'End trip';
  static const String retry = 'Retry';
  static const String join = 'Join';
  static const String copy = 'Copy';
  static const String endTripDialogTitle = 'End this trip?';
  static const String endTripDialogBody = 'Live tracking will stop for everyone.';
  static const String tripEnded = 'Trip ended.';
  // Takes an already-friendly MESSAGE (ApiException.message), never the
  // exception object. Interpolating an Object renders "ApiException (0): ..."
  // to the user. R4.
  static String failedToEndTrip(String message) => 'Could not end the trip. $message';

  // --- Trips screen ---
  static const String myTrips = 'My trips';
  static const String searchTrips = 'Search trips';
  static const String joinTripTooltip = 'Join trip';
  static const String newTrip = 'New trip';
  static const String joinedTripSuccess =
      'Joined trip. Open it to start tracking.';
  static String failedToJoinTrip(String message) => 'Could not join the trip. $message';
  static const String statActive = 'Active';
  static const String statTravelers = 'Travelers';
  static const String statDestinations = 'Dest.';
  static const String activeTripsHeader = 'Active Trips';
  static const String noTripsYet = 'No trips yet';
  static const String startATrip = 'Start a trip';
  static const String emptyTripsPrompt =
      'Start a trip and share the ID so your people can join.';
  static String noTripsMatch(String query) => "No trips match '$query'.";
  static const String joinTripTitle = 'Join a Trip';
  static const String joinTripPrompt = 'Enter the Trip ID your group leader shared.';
  static const String tripIdLabel = 'Trip ID';

  // --- Create trip screen ---
  static const String startNewTrip = 'Start new trip';
  static const String tripNameLabel = 'Trip name';
  static const String searchDestinationLabel = 'Search destination';
  static const String locateMeTooltip = 'Locate me';
  static const String startTripButton = 'Start trip';
  static const String tripCreatedTitle = 'Trip created';
  static const String shareTripIdPrompt =
      'Share this Trip ID so friends can join:';
  static const String openLiveMap = 'Open Live Map';
  static const String tripIdCopied = 'Trip ID copied to clipboard.';
  static const String locationPermissionRequired =
      'Location permission is required.';

  // --- Location access (re-checked every time the map opens or resumes) ---
  static const String locationServicesOff =
      "Location is turned off, so your trip isn't being recorded.";
  static const String locationPermissionDenied =
      "Location permission is needed to record your trip.";
  static const String locationPermissionBlocked =
      "Location permission is blocked, so your trip isn't being recorded.";
  static const String turnOnLocation = 'Turn on';
  static const String openSettings = 'Settings';
  static const String enterTripName = 'Please enter a trip name.';
  static const String selectDestination =
      'Please select or pin a destination location.';
  static String couldNotGetLocation(String message) =>
      'Could not get your location. $message';
  static String failedToStartTrip(String message) => 'Could not start the trip. $message';

  // --- Trip map screen ---
  static const String startingSync = 'Starting synchronization...';
  static const String syncComplete = 'Synchronization complete.';
  static String syncFailed(String message) => 'Sync did not complete. $message';
  static const String currentLocationUnavailable =
      'Current location not available yet.';
  static String destinationSnack(String name) => 'Destination: $name';
  static String noLocationUpdates(String label) =>
      'No location updates from $label yet.';
  static const String zoomInTooltip = 'Zoom in';
  static const String zoomOutTooltip = 'Zoom out';
  static const String recenterTooltip = 'Recenter on me';
  static const String syncOfflineTooltip = 'Sync offline points';
  static const String destinationFallback = 'Destination';
  static const String memberFallback = 'User';
  static const String meLabel = 'Me';
  static const String tripIdInfoLabel = 'TRIP ID';
  static const String statusSyncing = 'Syncing…';
  static const String statusOffline = 'Offline';

  // --- Profile screen ---
  static const String profileTitle = 'Profile';
  static const String travelSummary = 'Travel Summary';
  static const String tripHistory = 'Trip History';
  static const String account = 'Account';
  static const String darkMode = 'Dark mode';
  static const String logOut = 'Log out';
  static const String guest = 'Guest';
  static const String statTrips = 'Trips';
  static const String noPastTrips = 'No past trips yet.';

  // --- Trip cards & clusters ---
  static String travelersCount(int total) => '$total travelers';
  static String memberCount(int count) =>
      count == 1 ? '1 member' : '$count members';
  static const String shareTripTooltip = 'Share trip';

  // --- Trip share message ---
  static String tripShareMessage({required String title, required String tripId}) =>
      'Join my trip "$title" on $appName!\n'
      'Trip ID: $tripId\n'
      'Open the app, tap Join Trip, and paste this ID.';
}
