import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(const ProviderScope(child: WayfarerSyncApp()));
}

class WayfarerSyncApp extends StatelessWidget {
  const WayfarerSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wayfarer Sync',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3388FF),
          brightness: Brightness.light,
        ),
      ),
      home: const MainScaffoldPlaceholder(),
    );
  }
}

class MainScaffoldPlaceholder extends StatelessWidget {
  const MainScaffoldPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wayfarer Sync'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: const Center(
        child: Text(
          'Mobile App Environment Configured!\nReady for Offline Storage Layer.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
