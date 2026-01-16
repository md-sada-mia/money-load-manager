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

  /// Request CORE permissions (SMS, Phone, Contacts)
  /// Location/Bluetooth are requested on-demand by SyncManager
  static Future<bool> requestRequiredPermissions() async {
    // Basic permissions
    final perms = [
      Permission.sms,
      Permission.phone,
      Permission.contacts,
    ];

    final statuses = await perms.request();

    // Check core permissions
    bool granted = statuses[Permission.sms]!.isGranted && 
                   statuses[Permission.phone]!.isGranted &&
                   statuses[Permission.contacts]!.isGranted;
                   
    return granted;
  }

  /// Open app settings
  static Future<void> openSettings() async {
    await openAppSettings();
  }
}
