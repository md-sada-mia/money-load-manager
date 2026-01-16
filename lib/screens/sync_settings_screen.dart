
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
          _logs.insert(0, status); // Stream now sends full formatted log
          if (_logs.length > 100) _logs.removeLast();
        });
      }
    });

    // Restore existing logs
    setState(() {
      _logs.addAll(_syncManager.logs);
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

          // Connection Method Selection
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Connection Method',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    title: const Text('Direct Wi-Fi (Router)'),
                    subtitle: const Text('Requires same Wi-Fi network'),
                    secondary: const Icon(Icons.wifi),
                    value: _syncManager.useLan,
                    onChanged: (val) async {
                      await _syncManager.setUseLan(val);
                      setState(() {});
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Nearby Share (No Internet)'),
                    subtitle: const Text('Uses Bluetooth & Wi-Fi Direct'),
                    secondary: const Icon(Icons.wifi_tethering),
                    value: _syncManager.useNearby,
                    onChanged: (val) async {
                      await _syncManager.setUseNearby(val);
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
          ),
          
          if (_syncManager.role == SyncRole.master && _syncManager.isSyncing)
             Card(
                color: Colors.green[50],
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                       const Text('Server Active', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                       const SizedBox(height: 5),
                       if (_syncManager.useLan)
                         SelectableText(
                           'LAN IP: ${_syncManager.lanService.serverIp ?? "Waiting..."} : ${_syncManager.lanService.servicePort}',
                           style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                         ),
                       const SizedBox(height: 5),
                       const Text('Listening for connections...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
             ),


          const SizedBox(height: 20),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Activity Log', style: TextStyle(fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: () {
                    _syncManager.clearLogs();
                    setState(() {
                      _logs.clear();
                    });
                  },
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: const Text('Clear'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: Colors.redAccent,
                  ),
                ),
              ],
            ),
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
          
          // Service Control
          Card(
             margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
             child: SwitchListTile(
               title: const Text('Sync Service', style: TextStyle(fontWeight: FontWeight.bold)),
               subtitle: Text(_syncManager.isSyncing ? 'Running' : 'Stopped', style: TextStyle(color: _syncManager.isSyncing ? Colors.green : Colors.grey)),
               value: _syncManager.isSyncing,
               activeColor: Colors.teal,
               onChanged: (val) async {
                 if (val) {
                   await _syncManager.startSync();
                 } else {
                   await _syncManager.stopSync();
                 }
                 setState(() {});
               },
             ),
          ),
           const SizedBox(height: 10),
        ],
      ),
    );
  }
}
