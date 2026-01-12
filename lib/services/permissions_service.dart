import 'package:permission_handler/permission_handler.dart';

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

  /// Open app settings
  static Future<void> openSettings() async {
    await openAppSettings();
  }
}
