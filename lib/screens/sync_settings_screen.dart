
import 'package:flutter/material.dart';
import '../services/sync_manager.dart';
import '../services/sync_provider.dart';

class SyncSettingsScreen extends StatefulWidget {
  const SyncSettingsScreen({super.key});

  @override
  State<SyncSettingsScreen> createState() => _SyncSettingsScreenState();
}

class _SyncSettingsScreenState extends State<SyncSettingsScreen> {
  final SyncManager _syncManager = SyncManager();
  final List<String> _logs = [];
  bool _isInit = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _syncManager.init();
    
    _syncManager.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _logs.insert(0, "${DateTime.now().hour}:${DateTime.now().minute}:${DateTime.now().second} - $status");
          if (_logs.length > 50) _logs.removeLast();
        });
      }
    });

    setState(() {
      _isInit = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInit) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Synchronization'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Role Selection
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                   const Text(
                    'Device Role',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<SyncRole>(
                          title: const Text('Worker'),
                          subtitle: const Text('Sends data to Master'),
                          value: SyncRole.worker,
                          groupValue: _syncManager.role,
                          onChanged: (val) async {
                            if (val != null) {
                              await _syncManager.setRole(val);
                              setState(() {});
                            }
                          },
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<SyncRole>(
                          title: const Text('Master'),
                          subtitle: const Text('Receives data'),
                          value: SyncRole.master,
                          groupValue: _syncManager.role,
                          onChanged: (val) async {
                            if (val != null) {
                              await _syncManager.setRole(val);
                              setState(() {});
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.sync),
                label: Text(_syncManager.role == SyncRole.master ? 'Start Server' : 'Sync Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () {
                   _syncManager.startSync();
                },
              ),
            ),
          ),
          
          if (_syncManager.role == SyncRole.master)
            Padding(
               padding: const EdgeInsets.all(8.0),
               child: Text('Master Mode: Keep this screen open to receive data.', style: TextStyle(color: Colors.grey[600]),),
            ),


          const SizedBox(height: 20),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('Activity Log', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          
          // Log Console
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  return Text(
                    _logs[index],
                    style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 12),
                  );
                },
              ),
            ),
          ),
          
          TextButton(
             onPressed: () {
               _syncManager.stopSync();
             },
             child: const Text('Stop Sync Service', style: TextStyle(color: Colors.red)),
          ),
           const SizedBox(height: 10),
        ],
      ),
    );
  }
}
