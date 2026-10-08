import 'dart:io';
import 'package:geolocator/geolocator.dart';
import 'package:device_info_plus/device_info_plus.dart';

class GeolocationService {
  static Future<String?> getPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5),
      );
      return '${position.latitude.toStringAsFixed(6)},${position.longitude.toStringAsFixed(6)}';
    } catch (_) {
      return null;
    }
  }

  static Future<String> getDeviceInfo() async {
    final plugin = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        return '${info.brand} ${info.model} (Android ${info.version.release})';
      }
      if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        return '${info.name} (iOS ${info.systemVersion})';
      }
    } catch (_) {}
    return 'Mobile (${Platform.operatingSystem})';
  }

  static String getTimezone() {
    return DateTime.now().timeZoneName;
  }
}
