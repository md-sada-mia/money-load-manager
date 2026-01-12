import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'training_screen.dart';
import '../services/sms_listener.dart';
import '../services/default_patterns.dart';
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

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _smsMonitoring = prefs.getBool('sms_monitoring') ?? true;
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
                leading: const Icon(Icons.download),
                title: const Text('Load Default Patterns'),
                subtitle: const Text('Add common Bangladesh SMS patterns'),
                onTap: _loadDefaultPatterns,
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever),
                title: const Text('Clear All Data'),
                subtitle: const Text('Delete all transactions and patterns'),
                textColor: Theme.of(context).colorScheme.error,
                iconColor: Theme.of(context).colorScheme.error,
                onTap: _confirmClearData,
              ),
            ],
          ),
          const Divider(),
          if (kDebugMode) ...[
            _buildSection(
              'Developer Options',
              [
                ListTile(
                  leading: const Icon(Icons.school),
                  title: const Text('Pattern Training'),
                  subtitle: const Text('Train and export Regex patterns'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const TrainingScreen()),
                    );
                  },
                ),
              ],
            ),
            const Divider(),
          ],
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Historical SMS'),
        content: const Text(
          'This will scan SMS messages from the last 30 days and import any matching transactions. This may take a few moments.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isImporting = true);

    try {
      final count = await SmsListener.importHistoricalSms(days: 30);
      
      setState(() => _isImporting = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported $count transactions')),
        );
      }
    } catch (e) {
      setState(() => _isImporting = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing SMS: $e')),
        );
      }
    }
  }

  Future<void> _loadDefaultPatterns() async {
    try {
      final defaultPatterns = DefaultPatterns.getDefaultPatterns();
      
      // Check if patterns already exist
      final existingPatterns = await _db.getAllPatterns();
      if (existingPatterns.isNotEmpty) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Load Default Patterns'),
            content: const Text(
              'This will add common Bangladesh SMS patterns to your database. Existing patterns will not be affected.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Add Patterns'),
              ),
            ],
          ),
        );
        
        if (confirmed != true) return;
      }

      for (final pattern in defaultPatterns) {
        await _db.createPattern(pattern);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added ${defaultPatterns.length} default patterns')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading patterns: $e')),
        );
      }
    }
  }

  Future<void> _confirmClearData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
          'This will permanently delete all transactions, patterns, and summaries. This action cannot be undone.',
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
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _db.deleteAllData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All data cleared')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error clearing data: $e')),
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
}
