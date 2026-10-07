import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class SystemPermissionStatus {
  final bool notificationGranted;
  final bool storageAudioGranted;
  final bool batteryOptimizationIgnored;
  final bool bluetoothGranted;

  const SystemPermissionStatus({
    required this.notificationGranted,
    required this.storageAudioGranted,
    required this.batteryOptimizationIgnored,
    required this.bluetoothGranted,
  });

  bool get allCriticalGranted =>
      kIsWeb || (notificationGranted && (storageAudioGranted || Platform.isWindows));
}

class PermissionHubService extends ChangeNotifier {
  static final PermissionHubService instance = PermissionHubService._internal();
  PermissionHubService._internal();

  SystemPermissionStatus _status = const SystemPermissionStatus(
    notificationGranted: false,
    storageAudioGranted: false,
    batteryOptimizationIgnored: false,
    bluetoothGranted: false,
  );

  SystemPermissionStatus get status => _status;

  Future<void> refresh() async {
    if (kIsWeb) {
      _status = const SystemPermissionStatus(
        notificationGranted: true,
        storageAudioGranted: true,
        batteryOptimizationIgnored: true,
        bluetoothGranted: true,
      );
      notifyListeners();
      return;
    }

    bool notif = true;
    bool storage = true;
    bool battery = true;
    bool bt = true;

    if (Platform.isAndroid) {
      notif = await Permission.notification.isGranted;
      
      // On Android 13+ check audio permission, else storage
      final audioGranted = await Permission.audio.isGranted;
      final legacyStorageGranted = await Permission.storage.isGranted;
      final manageGranted = await Permission.manageExternalStorage.isGranted;
      storage = audioGranted || legacyStorageGranted || manageGranted;

      battery = await Permission.ignoreBatteryOptimizations.isGranted;
      bt = await Permission.bluetoothConnect.isGranted;
    }

    _status = SystemPermissionStatus(
      notificationGranted: notif,
      storageAudioGranted: storage,
      batteryOptimizationIgnored: battery,
      bluetoothGranted: bt,
    );
    notifyListeners();
  }

  Future<bool> requestNotificationPermission() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    final res = await Permission.notification.request();
    await refresh();
    return res.isGranted;
  }

  Future<bool> requestStoragePermission() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    await [
      Permission.audio,
      Permission.storage,
      Permission.manageExternalStorage,
    ].request();
    await refresh();
    return _status.storageAudioGranted;
  }

  Future<bool> requestBatteryOptimization() async {
    if (kIsWeb || !Platform.isAndroid) return true;
    final res = await Permission.ignoreBatteryOptimizations.request();
    await refresh();
    return res.isGranted;
  }

  Future<void> openSettings() async {
    await openAppSettings();
  }
}
