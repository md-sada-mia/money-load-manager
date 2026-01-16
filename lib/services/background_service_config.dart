import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:money_load_manager/database/database_helper.dart';
import 'package:money_load_manager/services/sync_manager.dart';
import 'package:money_load_manager/services/sms_listener.dart';
import 'package:money_load_manager/services/notification_service.dart';

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();
  
  // Create the notification channel explicitly first
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'sync_service_channel', // id
    'Sync Service', // title
    description: 'This channel is used for the Sync Service notification.', // description
    importance: Importance.low, // Importance must be low or higher
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  if (Platform.isAndroid) {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: false,
      isForegroundMode: true,
      notificationChannelId: 'sync_service_channel', // Must match above
      initialNotificationTitle: 'Money Load Manager',
      initialNotificationContent: 'Sync Service is active',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Ensure Flutter binding is initialized
  DartPluginRegistrant.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Core Services in this Isolate
  await DatabaseHelper.instance.database;
  await NotificationService().init();
  await SmsListener.initialize();
  await SyncManager().init();

  // Listen for Stop event
  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Keep alive logic is implicit in Foreground Service
  // But we can add a periodic timer if we need to poll something
  // For now, SyncManager listens to SmsListener stream which triggers actions.
}
