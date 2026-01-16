import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Instructions'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle(context, 'How Multi-Device Sync Works'),
          _buildInfoCard(
            context,
            'Device Roles',
            '• One device must be the MASTER (Receiver).\n'
            '• Other devices are WORKERS (Senders).\n'
            '• Workers send their SMS transactions to the Master automatically.',
            Icons.devices,
          ),
          
          _buildSectionTitle(context, 'Connection Methods'),
          _buildInfoCard(
            context,
            '1. Direct Wi-Fi (Recommended)',
            '• Both devices must be connected to the SAME Wi-Fi router.\n'
            '• Best for stable, long-range connection.\n'
            '• Requires Location permission to detect Wi-Fi.',
            Icons.wifi,
          ),
          _buildInfoCard(
            context,
            '2. Nearby Share (No Internet)',
            '• Connects devices directly without a router.\n'
            '• Uses Bluetooth and Wi-Fi Direct.\n'
            '• Good for field work where no Wi-Fi is available.\n'
            '• Requires Bluetooth & Location permissions.',
            Icons.wifi_tethering,
          ),

           _buildSectionTitle(context, 'Sync Settings'),
           _buildInfoCard(
            context,
            'Configuration',
            'Go to "Data Synchronization" settings to:\n'
            '• Select your device role (Master/Worker).\n'
            '• Enable "Direct Wi-Fi" or "Nearby" or both.\n'
            '• Permissions will be requested based on your choice.',
            Icons.settings_applications,
          ),
           _buildInfoCard(
            context,
            'Automatic Background Sync',
            '• The app will automatically try to sync when a new SMS arrives.\n'
            '• It will retry up to 10 times if connection fails.\n'
            '• A notification will appear if sync fails repeatedly.',
            Icons.sync_lock,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: Colors.teal,
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, String title, String content, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 28, color: Colors.teal),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    content,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
