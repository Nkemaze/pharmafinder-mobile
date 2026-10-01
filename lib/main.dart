import 'package:flutter/material.dart';

import 'screens/splash_screen.dart';
import 'services/connectivity_service.dart';
import 'services/offline_map_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OfflineMapService.instance.initialize();
  ConnectivityService.instance.watch();
  runApp(const PharmaTrackApp());
}

class PharmaTrackApp extends StatelessWidget {
  const PharmaTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PharmaTrack',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const SplashScreen(),
    );
  }
}
