import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'training_screen.dart';
import 'sms_tester_screen.dart';
import '../services/sms_listener.dart';
import '../database/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  bool _isImporting = false;
  bool _smsMonitoring = true;
  bool _saveUnknown = false;
  bool _saveKnown = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _smsMonitoring = prefs.getBool('sms_monitoring') ?? true;
      _saveUnknown = prefs.getBool('save_unknown_contacts') ?? false;
      _saveKnown = prefs.getBool('save_known_contacts') ?? false;
    });
  }

  Future<void> _toggleSmsMonitoring(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sms_monitoring', value);
    setState(() => _smsMonitoring = value);
    
    if (value) {
      await SmsListener.initialize();
    }
  }

  Future<void> _toggleSaveUnknown(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('save_unknown_contacts', value);
    setState(() => _saveUnknown = value);
    // Reload listener settings if needed, or listener will read from prefs dynamically
    // For now, no reload needed if listener reads pref on each event or re-initializes
    await SmsListener.updateSettings();
  }

  Future<void> _toggleSaveKnown(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('save_known_contacts', value);
    setState(() => _saveKnown = value);
    await SmsListener.updateSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          _buildSection(
            'SMS Monitoring',
            [
              SwitchListTile(
                title: const Text('Enable SMS Monitoring'),
                subtitle: const Text('Automatically detect transactions from SMS'),
                value: _smsMonitoring,
                onChanged: _toggleSmsMonitoring,
              ),
              SwitchListTile(
                title: const Text('Save Unknown Numbers'),
                subtitle: const Text('Track transactions from unknown senders'),
                value: _saveUnknown,
                onChanged: _toggleSaveUnknown,
              ),
              SwitchListTile(
                title: const Text('Save Saved Contacts'),
                subtitle: const Text('Track transactions from contacts'),
                value: _saveKnown,
                onChanged: _toggleSaveKnown,
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Import Historical SMS'),
                subtitle: const Text('Scan past SMS for transactions'),
                trailing: _isImporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                onTap: _isImporting ? null : _importHistoricalSms,
              ),
            ],
          ),
          const Divider(),
          _buildSection(
            'Data Management',
            [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Pattern Info'),
                subtitle: const Text('Default patterns are built-in. Database is for custom patterns only.'),
                enabled: false,
              ),
              ListTile(
                leading: const Icon(Icons.restore),
                title: const Text('Reset App'),
                subtitle: const Text('Delete all data and reset settings to default'),
                textColor: Theme.of(context).colorScheme.error,
                iconColor: Theme.of(context).colorScheme.error,
                onTap: _confirmResetApp,
              ),
            ],
          ),
          const Divider(),
          if (kDebugMode) ...[
            _buildSection(
              'Developer Options',
              [
                ListTile(
                  leading: const Icon(Icons.school, color: Colors.blue),
                  title: const Text('Pattern Training'),
                  subtitle: const Text('Train and export Regex patterns'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const TrainingScreen()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.science, color: Colors.orange),
                  title: const Text('SMS Tester'),
                  subtitle: const Text('Test patterns against raw text'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SmsTesterScreen()),
                    );
                  },
                ),
              ],
            ),
            const Divider(),
          ],
          _buildDeveloperInfo(context),
          const Divider(),
          _buildSection(
            'About',
            [
              const ListTile(
                leading: Icon(Icons.info),
                title: Text('Version'),
                subtitle: Text('1.0.0'),
              ),
              const ListTile(
                leading: Icon(Icons.security),
                title: Text('Privacy'),
                subtitle: Text('100% offline - no data leaves your device'),
              ),
              ListTile(
                leading: const Icon(Icons.description),
                title: const Text('About this app'),
                subtitle: const Text('Offline SMS transaction tracker'),
                onTap: () => _showAboutDialog(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...children,
      ],
    );
  }

  Future<void> _importHistoricalSms() async {
    // 1. Select Range Step
    final days = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Time Range'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 30),
            child: const Padding(
               padding: EdgeInsets.symmetric(vertical: 8),
               child: Text('Last 1 Month')
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 90),
            child: const Padding(
               padding: EdgeInsets.symmetric(vertical: 8),
               child: Text('Last 3 Months')
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 180),
            child: const Padding(
               padding: EdgeInsets.symmetric(vertical: 8),
               child: Text('Last 6 Months')
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 365),
            child: const Padding(
               padding: EdgeInsets.symmetric(vertical: 8),
               child: Text('Last 1 Year')
            ),
          ),
          const Divider(),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, -1), // Custom
            child: const Padding(
               padding: EdgeInsets.symmetric(vertical: 8),
               child: Text('Custom Range (Days)'),
            ),
          ),
        ],
      ),
    );

    if (days == null) return;
    
    int finalDays = days;
    if (days == -1) {
      // Show input dialog for custom days
      final customDays = await showDialog<int>(
        context: context,
        builder: (context) {
          final controller = TextEditingController();
          return AlertDialog(
            title: const Text('Enter Number of Days'),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'e.g., 45'),
              autofocus: true,
            ),
            actions: [
               TextButton(
                 onPressed: () => Navigator.pop(context),
                 child: const Text('Cancel'),
               ),
               FilledButton(
                 onPressed: () {
                   final val = int.tryParse(controller.text);
                   if (val != null && val > 0) {
                     Navigator.pop(context, val);
                   }
                 },
                 child: const Text('OK'),
               )
            ],
          );
        }
      );
      
      if (customDays == null) return;
      finalDays = customDays;
    }

    setState(() => _isImporting = true); // Block settings UI interaction
    
    // 2. Show Progress Dialog (Persistent)
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ImportProgressDialog(days: finalDays),
    ).then((_) {
      // Dialog closed (import done or error)
      setState(() => _isImporting = false);
    });
  }

  Future<void> _confirmResetApp() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset App'),
        content: const Text(
          'This will permanently delete all transactions, patterns, and reset all settings to default. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Reset App'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // 1. Clear Database
        await _db.deleteAllData();
        
        // 2. Clear SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        
        // 3. Reload Default Patterns
        await _db.reloadDefaultPatterns();
        
        // 4. Reset Local State
        setState(() {
          _smsMonitoring = true; // Default
          _saveUnknown = false; // Default
          _saveKnown = false; // Default
        });
        
        // 5. Update Listener Settings
        await SmsListener.updateSettings();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('App has been reset to factory defaults')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error resetting app: $e')),
          );
        }
      }
    }
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'Money Load Manager',
      applicationVersion: '1.0.0',
      applicationLegalese: '© 2026 Money Load Manager\n\n'
          'A 100% offline Android app for mobile financial service agents that automatically '
          'tracks daily transactions by reading incoming SMS in real time.',
      children: [
        const SizedBox(height: 16),
        const Text(
          'Features:\n'
          '• Automatic SMS transaction detection\n'
          '• Support for flexiload, bKash, and utility bills\n'
          '• Training manager for new SMS formats\n'
          '• Complete offline operation\n'
          '• Privacy-focused - no cloud sync',
        ),
      ],
    );
  }



  Widget _buildDeveloperInfo(BuildContext context) {
    return Column(
      children: [
        _buildSection(
          'Developer Info',
          [],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            children: [
              const CircleAvatar(
                radius: 50,
                backgroundImage: AssetImage('assets/developer.png'),
                backgroundColor: Colors.transparent,
              ),
              const SizedBox(height: 16),
              const Text(
                'Mehedi Hasan Mondol',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'AI IDE Specialist Windsurf / Antigravity &.. | Web App & Android Dev.',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              _buildContactTile(
                Icons.email, 
                'mehedihasanmondol.online@gmail.com',
                () => _launchUrl('mailto:mehedihasanmondol.online@gmail.com'),
              ),
              _buildContactTile(
                Icons.phone, 
                '01912336505',
                () => _launchUrl('tel:01912336505'),
              ),
              _buildContactTile(
                Icons.language, 
                'websitelimited.com',
                () => _launchUrl('https://websitelimited.com'),
              ),
              _buildContactTile(
                Icons.facebook, 
                'facebook.com/Md.Sada.Mia.bd',
                () => _launchUrl('https://facebook.com/Md.Sada.Mia.bd'),
              ),
              _buildContactTile(
                Icons.location_on, 
                'South Bagoan, Bagoan, Mothurapur, Doulotpur, Kushtia, 7052',
                null, // Address not clickable for now
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContactTile(IconData icon, String text, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  color: onTap != null ? Colors.blue : null, // Visual cue for clickable
                  decoration: onTap != null ? TextDecoration.underline : null,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not launch $urlString')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

class _ImportProgressDialog extends StatefulWidget {
  final int days;
  const _ImportProgressDialog({required this.days});

  @override
  State<_ImportProgressDialog> createState() => _ImportProgressDialogState();
}

class _ImportProgressDialogState extends State<_ImportProgressDialog> {
  double _progress = 0.0;
  String _status = 'Starting...';
  
  @override
  void initState() {
    super.initState();
    _startImport();
  }

  Future<void> _startImport() async {
    try {
      final count = await SmsListener.importHistoricalSms(
        days: widget.days,
        onProgress: (prog, status) {
          if (mounted) {
            setState(() {
              _progress = prog;
              _status = status;
            });
          }
        },
      );
      
      if (mounted) {
        Navigator.pop(context); // Close progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully imported $count transaction(s)')),
        );
      }
    } catch (e) {
      if (mounted) {
         Navigator.pop(context); // Close progress dialog
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Error: $e')),
         );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Importing SMS'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(value: _progress),
          const SizedBox(height: 16),
          Text(_status, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('${(_progress * 100).toStringAsFixed(1)}%', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
