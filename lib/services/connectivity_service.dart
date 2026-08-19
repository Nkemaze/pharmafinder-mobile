import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Tracks internet connectivity so the UI can show the offline banner /
/// offline screen described by the design.
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();

  /// True when we believe the device has an internet connection.
  final ValueNotifier<bool> isOnline = ValueNotifier<bool>(true);

  Stream<bool> get onlineStream => _connectivity.onConnectivityChanged
      .map((results) => results.any((r) => r != ConnectivityResult.none));

  /// Starts listening to connectivity changes.
  void watch() {
    _connectivity.onConnectivityChanged.listen((results) {
      isOnline.value = results.any((r) => r != ConnectivityResult.none);
    });
  }

  /// One-shot connectivity check.
  Future<bool> checkNow() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final online = results.any((r) => r != ConnectivityResult.none);
      isOnline.value = online;
      return online;
    } catch (_) {
      return true; // assume online on error so we don't trap the user offline
    }
  }
}
