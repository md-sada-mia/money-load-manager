import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/sms_listener.dart';
import 'services/permissions_service.dart';
import 'database/database_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize database
  await DatabaseHelper.instance.database;
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Money Load Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        cardTheme: const CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        cardTheme: const CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
      ),
      home: const PermissionWrapper(),
    );
  }
}

class PermissionWrapper extends StatefulWidget {
  const PermissionWrapper({super.key});

  @override
  State<PermissionWrapper> createState() => _PermissionWrapperState();
}

class _PermissionWrapperState extends State<PermissionWrapper> {
  bool _isCheckingPermissions = true;
  bool _hasPermissions = false;
  bool _isInitializing = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final hasPermissions = await PermissionsService.hasSmsPermissions();
    setState(() {
      _hasPermissions = hasPermissions;
      _isCheckingPermissions = false;
    });

    if (hasPermissions) {
      await _initializeApp();
    }
  }

  Future<void> _requestPermissions() async {
    setState(() => _isInitializing = true);
    
    final granted = await PermissionsService.requestSmsPermissions();
    
    if (granted) {
      await _initializeApp();
      setState(() {
        _hasPermissions = true;
        _isInitializing = false;
      });
    } else {
      setState(() => _isInitializing = false);
      if (mounted) {
        _showPermissionDeniedDialog();
      }
    }
  }

  Future<void> _initializeApp() async {
    // Initialize SMS listener
    await SmsListener.initialize();
    
    // Note: Default patterns are NOT loaded into database
    // They are checked directly from code in sms_parser.dart
    // Database is only for user-created custom patterns
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permissions Required'),
        content: const Text(
          'This app needs SMS permissions to automatically detect transactions from SMS messages. '
          'Without these permissions, the app cannot function.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              PermissionsService.openSettings();
            },
            child: const Text('Open Settings'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _requestPermissions();
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingPermissions) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_hasPermissions) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.sms,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'SMS Permissions Required',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Money Load Manager needs permission to read SMS messages to automatically detect and track your transactions.',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: _isInitializing ? null : _requestPermissions,
                  icon: _isInitializing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check),
                  label: Text(_isInitializing ? 'Initializing...' : 'Grant Permission'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.security,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Privacy Guaranteed',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• 100% offline operation\n'
                          '• No data sent to servers\n'
                          '• All data stays on your device\n'
                          '• No internet required',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const HomeScreen();
  }
}
