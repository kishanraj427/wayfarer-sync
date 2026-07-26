import 'package:flutter/material.dart';
import '../../../core/constants/appStrings.dart';
import '../services/locationPermissionHandler.dart';

/// Guards against stacking dialogs when several watchers (or a watcher and the
/// map screen) notice the same problem at the same moment.
bool _dialogOpen = false;

/// Shows a modal explaining why location is unavailable, with a button that
/// opens the screen which can fix it.
///
/// Modal rather than a snackbar: the app cannot record a trip in this state,
/// and a snackbar is easy to miss and trivially overwritten by any other
/// message the screen happens to show.
Future<void> showLocationAccessDialog(
  BuildContext context,
  LocationAccess access,
) async {
  if (_dialogOpen || access == LocationAccess.granted) return;
  _dialogOpen = true;
  try {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.location_off_outlined),
        title: const Text(AppStrings.locationNeededTitle),
        content: Text(access.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(AppStrings.notNow),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              LocationPermissionHandler.openSettingsFor(access);
            },
            child: Text(access.actionLabel),
          ),
        ],
      ),
    );
  } finally {
    _dialogOpen = false;
  }
}

/// Re-checks location access when mounted and on every app resume, prompting
/// if it is unavailable.
///
/// Wrapping the signed-in shell is what makes "device location is off" visible
/// on app open. Checking only where tracking starts is not enough: the user
/// lands on the trips list, not the map, so nothing would ever ask them.
class LocationAccessWatcher extends StatefulWidget {
  final Widget child;

  const LocationAccessWatcher({super.key, required this.child});

  @override
  State<LocationAccessWatcher> createState() => _LocationAccessWatcherState();
}

class _LocationAccessWatcherState extends State<LocationAccessWatcher> {
  AppLifecycleListener? _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _check);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _check();
    });
  }

  Future<void> _check() async {
    final access = await LocationPermissionHandler.check();
    if (!mounted || access == LocationAccess.granted) return;
    await showLocationAccessDialog(context, access);
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
