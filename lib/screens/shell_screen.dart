import 'package:flutter/material.dart';

import '../services/connectivity_service.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/offline_banner.dart';
import 'home_screen.dart';
import 'map_screen.dart';
import 'nearby_screen.dart';
import 'settings_screen.dart';

/// Main scaffold hosting the four tabs behind the bottom navigation:
/// Home, Nearby, Map, Settings.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: ConnectivityService.instance.isOnline,
              builder: (context, online, _) {
                return online
                    ? const SizedBox.shrink()
                    : const OfflineBanner();
              },
            ),
            Expanded(
              child: IndexedStack(
                index: _index,
                children: [
                  const HomeScreen(),
                  const NearbyScreen(),
                  const MapScreen(showAppBar: false),
                  const SettingsScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}
