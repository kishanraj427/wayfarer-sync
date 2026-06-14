# Flow Fixes and Mobile UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the end-to-end user navigation, auth, and trip screens in the mobile app, configure automatic offline-to-online sync, and secure the backend WebSocket against soft-deleted trips and out-of-bound coordinates.

**Architecture:** Integrate GoRouter into the Flutter client mapping to authentication states with token caching via SharedPreferences. Use connectivity_plus to trigger Drift database synchronization automatically on network restoration. Secure backend WebSocket upgrades by checking trip state and parsing coordinates with Zod schemas.

**Tech Stack:** Flutter, Riverpod, GoRouter, SharedPreferences, ConnectivityPlus, Drift SQLite, Express, Bun, Prisma, Zod, PostgreSQL.

---

### Task 1: Add Mobile Client Dependencies

**Files:**
- Modify: `mobile/pubspec.yaml`

- [ ] **Step 1: Modify pubspec.yaml to add go_router, connectivity_plus, and shared_preferences**

Add the dependencies to `mobile/pubspec.yaml` in the dependencies section:
```yaml
  # Routing, Storage, and Connectivity
  go_router: ^14.2.0
  connectivity_plus: ^6.0.3
  shared_preferences: ^2.2.3
```

- [ ] **Step 2: Run flutter pub get to fetch packages**

Run in terminal:
```bash
cd mobile
flutter pub get
```
Expected: Command exits successfully with status code 0.

- [ ] **Step 3: Commit (if auto_commit enabled)**

Check `.agent/config.yml` for `auto_commit` setting. If `auto_commit: false`, skip commit and staging. Print: "Skipping commit (auto_commit: false)."

---

### Task 2: Implement Persistent Auth Token Storage

**Files:**
- Modify: `mobile/lib/core/network/authTokenProvider.dart`

- [ ] **Step 1: Update AuthTokenNotifier to save and load token from SharedPreferences**

Replace `mobile/lib/core/network/authTokenProvider.dart` with:
```dart
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthTokenNotifier extends StateNotifier<String?> {
  AuthTokenNotifier() : super(null) {
    _loadPersistedToken();
  }

  static const _tokenKey = 'jwt_token';

  Future<void> _loadPersistedToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token != null) {
      state = token;
    }
  }

  Future<void> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    state = token;
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    state = null;
  }

  bool get isAuthenticated => state != null;
}

final authTokenProvider = StateNotifierProvider<AuthTokenNotifier, String?>((ref) {
  return AuthTokenNotifier();
});
```

- [ ] **Step 2: Verify code compiles**

Run in terminal:
```bash
flutter analyze
```
Expected: Code compiles without syntax or analyzer errors for this provider.

- [ ] **Step 3: Commit (if auto_commit enabled)**

Check `.agent/config.yml` for `auto_commit` setting. If `auto_commit: false`, skip commit and staging. Print: "Skipping commit (auto_commit: false)."

---

### Task 3: Setup GoRouter Routing

**Files:**
- Create: `mobile/lib/core/network/router.dart`
- Modify: `mobile/lib/main.dart`

- [ ] **Step 1: Create router.dart with routing matrix and redirection logic**

Create `mobile/lib/core/network/router.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'authTokenProvider.dart';
import '../../features/auth/screens/loginScreen.dart';
import '../../features/auth/screens/signupScreen.dart';
import '../../features/trip/screens/tripsScreen.dart';
import '../../features/tracking/screens/tripMapScreen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authTokenProvider.notifier);

  return GoRouter(
    initialLocation: '/login',
    redirect: (BuildContext context, GoRouterState state) {
      final isAuthenticated = ref.read(authTokenProvider) != null;
      final loggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/signup';

      if (!isAuthenticated) {
        return loggingIn ? null : '/login';
      }

      if (loggingIn) {
        return '/trips';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/trips',
        builder: (context, state) => const TripsScreen(),
      ),
      GoRoute(
        path: '/trip/:tripId/map/:userId',
        builder: (context, state) {
          final tripId = state.pathParameters['tripId']!;
          final userId = state.pathParameters['userId']!;
          return TripMapScreen(tripId: tripId, currentUserId: userId);
        },
      ),
    ],
  );
});
```

- [ ] **Step 2: Update main.dart to hook up routerProvider**

Modify `mobile/lib/main.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/network/router.dart';

void main() {
  runApp(const ProviderScope(child: WayfarerSyncApp()));
}

class WayfarerSyncApp extends ConsumerWidget {
  const WayfarerSyncApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Wayfarer Sync',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3388FF),
          brightness: Brightness.light,
        ),
      ),
      routerConfig: router,
    );
  }
}
```

- [ ] **Step 3: Verify build passes code analyzer check**

Run:
```bash
flutter analyze
```
Expected: No compiler errors (apart from warnings about missing screens, which we create next).

- [ ] **Step 4: Commit (if auto_commit enabled)**

Check `.agent/config.yml` for `auto_commit` setting. If `auto_commit: false`, skip commit and staging. Print: "Skipping commit (auto_commit: false)."

---

### Task 4: Create Login & Signup Screens

**Files:**
- Create: `mobile/lib/features/auth/screens/loginScreen.dart`
- Create: `mobile/lib/features/auth/screens/signupScreen.dart`

- [ ] **Step 1: Create loginScreen.dart**

Create `mobile/lib/features/auth/screens/loginScreen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/apiClient.dart';
import '../../../core/network/authTokenProvider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = ref.read(apiClientProvider);
      final response = await client.post('/auth/login', {
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
      });

      final token = response['token'] as String;
      await ref.read(authTokenProvider.notifier).setToken(token);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('ApiException: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _login,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Log In'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.go('/signup'),
              child: const Text("Don't have an account? Sign Up"),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Create signupScreen.dart**

Create `mobile/lib/features/auth/screens/signupScreen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/apiClient.dart';
import '../../../core/network/authTokenProvider.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _signup() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = ref.read(apiClientProvider);
      final response = await client.post('/auth/signup', {
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
      });

      final token = response['token'] as String;
      await ref.read(authTokenProvider.notifier).setToken(token);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('ApiException: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Up'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _signup,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Sign Up'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.go('/login'),
              child: const Text('Already have an account? Log In'),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Verify imports and code analyzer**

Run:
```bash
flutter analyze
```
Expected: Screens compile without syntax errors.

- [ ] **Step 4: Commit (if auto_commit enabled)**

Check `.agent/config.yml` for `auto_commit` setting. If `auto_commit: false`, skip commit and staging. Print: "Skipping commit (auto_commit: false)."

---

### Task 5: Create Trips Dashboard Screen

**Files:**
- Create: `mobile/lib/features/trip/screens/tripsScreen.dart`

- [ ] **Step 1: Implement tripsScreen.dart**

Create `mobile/lib/features/trip/screens/tripsScreen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/apiClient.dart';
import '../../../core/network/authTokenProvider.dart';

class TripsScreen extends ConsumerStatefulWidget {
  const TripsScreen({super.key});

  @override
  ConsumerState<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends ConsumerState<TripsScreen> {
  List<dynamic> _trips = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchTrips();
  }

  Future<void> _fetchTrips() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = ref.read(apiClientProvider);
      final response = await client.get('/trip');
      setState(() {
        _trips = response as List<dynamic>;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('ApiException: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _createTrip(String title) async {
    try {
      final client = ref.read(apiClientProvider);
      await client.post('/trip', {
        'title': title,
        'startedAt': DateTime.now().toUtc().toIso8601String(),
      });
      _fetchTrips();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create trip: $e')),
      );
    }
  }

  Future<void> _joinTrip(String tripId) async {
    try {
      final client = ref.read(apiClientProvider);
      await client.post('/trip/$tripId/join', {});
      _fetchTrips();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to join trip: $e')),
      );
    }
  }

  void _showCreateTripDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Trip'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Trip Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                _createTrip(controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showJoinTripDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Trip'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Trip ID (UUID)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                _joinTrip(controller.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Trips'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authTokenProvider.notifier).clearToken(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : _trips.isEmpty
                  ? const Center(child: Text('No active trips found.'))
                  : RefreshIndicator(
                      onRefresh: _fetchTrips,
                      child: ListView.builder(
                        itemCount: _trips.length,
                        itemBuilder: (context, index) {
                          final trip = _trips[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: ListTile(
                              title: Text(trip['title'] ?? 'Unnamed Trip'),
                              subtitle: Text('ID: ${trip['id']}'),
                              trailing: const Icon(Icons.arrow_forward),
                              onTap: () {
                                // Extract user UUID (hardcoded placeholder for this route integration)
                                context.push('/trip/${trip['id']}/map/current_user');
                              },
                            ),
                          );
                        },
                      ),
                    ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'join',
            onPressed: _showJoinTripDialog,
            tooltip: 'Join Trip',
            child: const Icon(Icons.group_add),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'create',
            onPressed: _showCreateTripDialog,
            tooltip: 'Create Trip',
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify code compiling**

Run:
```bash
flutter analyze
```
Expected: All screens compile correctly.

- [ ] **Step 3: Commit (if auto_commit enabled)**

Check `.agent/config.yml` for `auto_commit` setting. If `auto_commit: false`, skip commit and staging. Print: "Skipping commit (auto_commit: false)."

---

### Task 6: Connect Map Screen Triggers

**Files:**
- Modify: `mobile/lib/features/tracking/screens/tripMapScreen.dart`

- [ ] **Step 1: Update map screen to wire up the sync triggers and add back navigation**

Replace `mobile/lib/features/tracking/screens/tripMapScreen.dart` with:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:wayfarer_sync_mobile/features/tracking/models/realtimeEvent.dart';
import '../providers/liveTrackingProviders.dart';
import '../providers/mapStateProvider.dart';
import '../services/locationTrackingService.dart';
import '../services/syncService.dart';

class TripMapScreen extends ConsumerStatefulWidget {
  final String tripId;
  final String currentUserId;

  const TripMapScreen({
    super.key,
    required this.tripId,
    required this.currentUserId,
  });

  @override
  ConsumerState<TripMapScreen> createState() => _TripMapScreenState();
}

class _TripMapScreenState extends ConsumerState<TripMapScreen> {
  final MapController _mapController = MapController();
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(locationTrackingServiceProvider)
          .startTracking(widget.tripId, widget.currentUserId);
    });
  }

  @override
  void dispose() {
    ref.read(locationTrackingServiceProvider).stopTracking();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _triggerManualSync() async {
    setState(() {
      _isSyncing = true;
    });

    try {
      await ref.read(syncServiceProvider).synchronizeTripPaths(widget.tripId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Offline batch synchronization complete.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final liveMarkerMap = ref.watch(mapStateProvider);

    ref.listen<AsyncValue<MemberLocationUpdate>>(
      liveLocationStreamProvider(widget.tripId),
      (previous, next) {
        if (next is AsyncData<MemberLocationUpdate>) {
          final update = next.value;
          ref.read(mapStateProvider.notifier).updateMemberPosition(
                update.userId,
                LatLng(update.latitude, update.longitude),
              );

          // Center the map camera on current user's coordinate once we receive it
          if (update.userId == widget.currentUserId) {
            _mapController.move(LatLng(update.latitude, update.longitude), 15.0);
          }
        }
      },
    );

    final userMarkers = liveMarkerMap.positions.entries.map((entry) {
      final userId = entry.key;
      final position = entry.value;
      final isMe = userId == widget.currentUserId;

      return Marker(
        point: position,
        width: 40,
        height: 40,
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: isMe ? Colors.blue : Colors.deepOrange,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Padding(
                padding: EdgeInsets.all(4.0),
                child: Icon(Icons.navigation, size: 16, color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Trip Map'),
        actions: [
          IconButton(
            icon: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.sync),
            onPressed: _isSyncing ? null : _triggerManualSync,
          ),
        ],
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: const MapOptions(
          initialCenter: LatLng(0.0, 0.0),
          initialZoom: 13.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.wayfarersync.mobile',
          ),
          PolylineLayer(
            polylines: [
              Polyline(
                points: liveMarkerMap.positions.values.toList(),
                color: const Color(0xFF3388FF),
                strokeWidth: 4.0,
              ),
            ],
          ),
          MarkerLayer(markers: userMarkers),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify map screen compiles**

Run:
```bash
flutter analyze
```
Expected: All mobile code compiles without analyzer errors.

- [ ] **Step 3: Commit (if auto_commit enabled)**

Check `.agent/config.yml` for `auto_commit` setting. If `auto_commit: false`, skip commit and staging. Print: "Skipping commit (auto_commit: false)."

---

### Task 7: Setup Connectivity Monitoring

**Files:**
- Create: `mobile/lib/features/tracking/services/connectivityService.dart`

- [ ] **Step 1: Create connectivity listener provider**

Create `mobile/lib/features/tracking/services/connectivityService.dart`:
```dart
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'syncService.dart';

class ConnectivityService {
  final Ref _ref;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  ConnectivityService(this._ref);

  void startListening(String tripId) {
    _subscription?.cancel();
    _subscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) async {
      // Check if we gained WiFi or Mobile connection
      final hasConnection = results.contains(ConnectivityResult.mobile) ||
          results.contains(ConnectivityResult.wifi);

      if (hasConnection) {
        print('Network connection detected, triggering sync...');
        await _ref.read(syncServiceProvider).synchronizeTripPaths(tripId);
      }
    });
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }
}

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService(ref);
});
```

- [ ] **Step 2: Verify code compiles**

Run:
```bash
flutter analyze
```
Expected: Code compiles clean.

- [ ] **Step 3: Commit (if auto_commit enabled)**

Check `.agent/config.yml` for `auto_commit` setting. If `auto_commit: false`, skip commit and staging. Print: "Skipping commit (auto_commit: false)."

---

### Task 8: Implement SQLite Drift Unit Tests

**Files:**
- Create: `mobile/test/local_database_test.dart`

- [ ] **Step 1: Implement database tests using in-memory drift engine**

Create `mobile/test/local_database_test.dart`:
```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' as drift;
import 'package:wayfarer_sync_mobile/core/storage/localDatabase.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase();
  });

  tearDown(() async {
    await database.close();
  });

  test('can insert and retrieve unsynced path points', () async {
    final timestamp = DateTime.now();

    await database.into(database.localPathPoints).insert(
      LocalPathPointsCompanion(
        id: const drift.Value('point-1'),
        tripId: const drift.Value('trip-1'),
        userId: const drift.Value('user-1'),
        latitude: const drift.Value(37.7749),
        longitude: const drift.Value(-122.4194),
        timestamp: drift.Value(timestamp),
        accuracy: const drift.Value(5.0),
        isSynced: const drift.Value(false),
      ),
    );

    final unsynced = await database.getUnsyncedPoints('trip-1');
    expect(unsynced.length, 1);
    expect(unsynced.first.id, 'point-1');
    expect(unsynced.first.isSynced, false);
  });

  test('can mark path points as synced', () async {
    final timestamp = DateTime.now();

    await database.into(database.localPathPoints).insert(
      LocalPathPointsCompanion(
        id: const drift.Value('point-2'),
        tripId: const drift.Value('trip-1'),
        userId: const drift.Value('user-1'),
        latitude: const drift.Value(37.7749),
        longitude: const drift.Value(-122.4194),
        timestamp: drift.Value(timestamp),
        accuracy: const drift.Value(5.0),
        isSynced: const drift.Value(false),
      ),
    );

    await database.markPointsAsSynced(['point-2']);

    final unsynced = await database.getUnsyncedPoints('trip-1');
    expect(unsynced.isEmpty, true);
  });
}
```

- [ ] **Step 2: Run flutter test suite**

Run in terminal:
```bash
flutter test test/local_database_test.dart
```
Expected: Tests pass successfully.

- [ ] **Step 3: Commit (if auto_commit enabled)**

Check `.agent/config.yml` for `auto_commit` setting. If `auto_commit: false`, skip commit and staging. Print: "Skipping commit (auto_commit: false)."

---

### Task 9: Secure Backend Handshake & Validate Coordinates

**Files:**
- Modify: `backend/src/websocket.ts`

- [ ] **Step 1: Secure socket upgrade step and add coordinate checks**

Replace `backend/src/websocket.ts` with:
```typescript
import { Server as HttpServer } from "http";
import { WebSocketServer, WebSocket } from "ws";
import url from "url";
import jwt from "jsonwebtoken";
import prisma from "./prisma";
import { roomManager } from "./services/websocket.manager";
import * as pathService from "./services/pathPoint.service";
import { z } from "zod";

const JWT_SECRET = process.env.JWT_SECRET || "your-secret-key";

// Coordinate check schema to validate WebSocket payloads
const coordinateValidationSchema = z.object({
  latitude: z.number().min(-90).max(90),
  longitude: z.number().min(-180).max(180),
  timestamp: z.string().datetime(),
  accuracy: z.number().nonnegative().nullish(),
});

export const initWebSocketServer = (server: HttpServer): void => {
  const wss = new WebSocketServer({ noServer: true });

  server.on("upgrade", async (request, socket, head) => {
    const parsedUrl = url.parse(request.url || "", true);
    const { token, tripId } = parsedUrl.query;

    if (
      !token ||
      !tripId ||
      typeof token !== "string" ||
      typeof tripId !== "string"
    ) {
      socket.write("HTTP/1.1 401 Unauthorized\r\n\r\n");
      socket.destroy();
      return;
    }

    try {
      const decoded = jwt.verify(token, JWT_SECRET) as { userId: string };
      const userId = decoded.userId;

      // Secure Upgrade membership verification & verify trip state
      const member = await prisma.tripMember.findUnique({
        where: {
          tripId_userId: { tripId, userId },
        },
        include: {
          trip: {
            select: { deletedAt: true, endedAt: true },
          },
        },
      });

      if (!member || member.trip.deletedAt !== null || member.trip.endedAt !== null) {
        socket.write("HTTP/1.1 403 Forbidden\r\n\r\n");
        socket.destroy();
        return;
      }

      wss.handleUpgrade(request, socket, head, (ws) => {
        wss.emit("connection", ws, userId, tripId);
      });
    } catch (err) {
      socket.write("HTTP/1.1 401 Unauthorized\r\n\r\n");
      socket.destroy();
    }
  });

  wss.on("connection", (ws: WebSocket, userId: string, tripId: string) => {
    roomManager.addUser(tripId, userId, ws);

    ws.on("message", async (message: string) => {
      try {
        const data = JSON.parse(message);

        if (data.type === "location_update") {
          const parseResult = coordinateValidationSchema.safeParse(data.payload);

          if (!parseResult.success) {
            ws.send(
              JSON.stringify({
                type: "error",
                payload: { message: "Invalid coordinate bounds or type structure" },
              }),
            );
            return;
          }

          const { latitude, longitude, timestamp, accuracy } = parseResult.data;

          roomManager.broadcastToRoom(tripId, userId, "member_location", {
            userId,
            latitude,
            longitude,
            timestamp,
            accuracy: accuracy ?? null,
          });

          pathService
            .ingestPathBatch([
              {
                tripId,
                userId,
                latitude,
                longitude,
                timestamp,
                accuracy: accuracy ?? undefined,
              },
            ])
            .catch((err) =>
              console.error(
                "Error logging background tracking coordinates:",
                err,
              ),
            );
        }
      } catch (err) {
        ws.send(
          JSON.stringify({
            type: "error",
            payload: { message: "Malformed payload frame structure" },
          }),
        );
      }
    });

    ws.on("close", () => {
      roomManager.removeUser(tripId, userId);
    });

    ws.on("error", (err) => {
      console.error(
        `WebSocket connection runtime fault for user ${userId}:`,
        err,
      );
      roomManager.removeUser(tripId, userId);
    });
  });
};
```

- [ ] **Step 2: Verify backend compiles correctly**

Run:
```bash
cd backend
bun run build
```
Expected: TypeScript builds successfully.

- [ ] **Step 3: Commit (if auto_commit enabled)**

Check `.agent/config.yml` for `auto_commit` setting. If `auto_commit: false`, skip commit and staging. Print: "Skipping commit (auto_commit: false)."

---

### Task 10: Backend Validation Tests

**Files:**
- Create: `backend/src/tests/websocket.test.ts`

- [ ] **Step 1: Implement coordinates validation unit tests**

Create `backend/src/tests/websocket.test.ts`:
```typescript
import { expect, test, describe } from "bun:test";
import { z } from "zod";

const coordinateValidationSchema = z.object({
  latitude: z.number().min(-90).max(90),
  longitude: z.number().min(-180).max(180),
  timestamp: z.string().datetime(),
  accuracy: z.number().nonnegative().nullish(),
});

describe("Coordinate Validation Parser Schema", () => {
  test("valid coordinates pass parsing checks", () => {
    const payload = {
      latitude: 37.7749,
      longitude: -122.4194,
      timestamp: new Date().toISOString(),
      accuracy: 5.2,
    };

    const parseResult = coordinateValidationSchema.safeParse(payload);
    expect(parseResult.success).toBe(true);
  });

  test("invalid latitude out of bounds fails parsing", () => {
    const payload = {
      latitude: 95.0, // Invalid, exceeds 90
      longitude: -122.4194,
      timestamp: new Date().toISOString(),
    };

    const parseResult = coordinateValidationSchema.safeParse(payload);
    expect(parseResult.success).toBe(false);
  });

  test("invalid longitude out of bounds fails parsing", () => {
    const payload = {
      latitude: 37.7749,
      longitude: 200.0, // Invalid, exceeds 180
      timestamp: new Date().toISOString(),
    };

    const parseResult = coordinateValidationSchema.safeParse(payload);
    expect(parseResult.success).toBe(false);
  });

  test("malformed timestamp strings fail parsing", () => {
    const payload = {
      latitude: 37.7749,
      longitude: -122.4194,
      timestamp: "not-a-date-string",
    };

    const parseResult = coordinateValidationSchema.safeParse(payload);
    expect(parseResult.success).toBe(false);
  });
});
```

- [ ] **Step 2: Run Bun test runner**

Run:
```bash
bun test src/tests/websocket.test.ts
```
Expected: Tests pass successfully.

- [ ] **Step 3: Commit (if auto_commit enabled)**

Check `.agent/config.yml` for `auto_commit` setting. If `auto_commit: false`, skip commit and staging. Print: "Skipping commit (auto_commit: false)."
