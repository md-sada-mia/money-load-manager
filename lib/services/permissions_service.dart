import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

/// Service for managing app permissions
class PermissionsService {
  /// Check if SMS permissions are granted
  static Future<bool> hasSmsPermissions() async {
    final smsStatus = await Permission.sms.status;
    final phoneStatus = await Permission.phone.status;
    return smsStatus.isGranted && phoneStatus.isGranted;
  }

  /// Request SMS permissions
  static Future<bool> requestSmsPermissions() async {
    final statuses = await [
      Permission.sms,
      Permission.phone,
    ].request();

    return statuses[Permission.sms]!.isGranted && 
           statuses[Permission.phone]!.isGranted;
  }

  /// Check if storage permissions are granted
  static Future<bool> hasStoragePermissions() async {
    if (await Permission.storage.isPermanentlyDenied) {
      return false;
    }
    return await Permission.storage.isGranted;
  }

  /// Request storage permissions (for export)
  static Future<bool> requestStoragePermissions() async {
    final status = await Permission.storage.request();
    return status.isGranted;
  }

  /// Check if contacts permissions are granted
  static Future<bool> hasContactsPermissions() async {
    return await Permission.contacts.isGranted;
  }

  /// Request contacts permissions
  static Future<bool> requestContactsPermissions() async {
    final status = await Permission.contacts.request();
    return status.isGranted;
  }

  /// Request ALL required permissions (SMS, Phone, Contacts, Location, Bluetooth)
  /// This helps avoid conflicts by requesting everything at once before plugins initialize
  static Future<bool> requestRequiredPermissions() async {
    // Basic permissions
    final perms = [
      Permission.sms,
      Permission.phone,
      Permission.contacts,
      Permission.location, // Required for Sync (LAN/Nearby)
    ];

    // Check Android SDK Version to conditionally add Bluetooth permissions
    if (Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final sdkInt = androidInfo.version.sdkInt;

      // Android 12+ (SDK 31) requires explicit Bluetooth permissions
      if (sdkInt >= 31) {
        perms.addAll([
          Permission.bluetoothScan,
          Permission.bluetoothAdvertise,
          Permission.bluetoothConnect,
        ]);
      }
      
      // Android 13+ (SDK 33) requires Nearby Wifi Devices
      if (sdkInt >= 33) {
        perms.add(Permission.nearbyWifiDevices);
      }
    }

    final statuses = await perms.request();

    // Check core permissions
    bool granted = statuses[Permission.sms]!.isGranted && 
                   statuses[Permission.phone]!.isGranted &&
                   statuses[Permission.contacts]!.isGranted &&
                   statuses[Permission.location]!.isGranted;
                   
    return granted;
  }

  /// Open app settings
  static Future<void> openSettings() async {
    await openAppSettings();
  }
}
