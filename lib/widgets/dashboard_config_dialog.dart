import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'transaction_icon.dart';
import '../utils/logo_helper.dart';

class DashboardConfigDialog extends StatefulWidget {
  final List<String> currentOrder;
  final Set<String> alwaysShow;

  const DashboardConfigDialog({
    super.key,
    required this.currentOrder,
    required this.alwaysShow,
  });

  @override
  State<DashboardConfigDialog> createState() => _DashboardConfigDialogState();
}

class _DashboardConfigDialogState extends State<DashboardConfigDialog> {
  late List<String> _orderedTypes;
  late Set<String> _alwaysShow;

  @override
  void initState() {
    super.initState();
    _orderedTypes = List.from(widget.currentOrder);
    _alwaysShow = Set.from(widget.alwaysShow);
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Save order
    await prefs.setStringList('dashboard_card_order', _orderedTypes);

    // Save always show
    await prefs.setStringList('dashboard_always_show', _alwaysShow.toList());

    if (mounted) {
      Navigator.pop(context, true); // Return true to indicate changes
    }
  }

  void _toggleAlwaysShow(String type, bool value) {
    setState(() {
      if (value) {
        _alwaysShow.add(type);
      } else {
        _alwaysShow.remove(type);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Customize Dashboard'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400, // Fixed height for list
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                'Long press & drag to reorder.\nToggle switch to always show.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
            const Divider(),
            Expanded(
              child: ReorderableListView(
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (oldIndex < newIndex) {
                      newIndex -= 1;
                    }
                    final item = _orderedTypes.removeAt(oldIndex);
                    _orderedTypes.insert(newIndex, item);
                  });
                },
                children: _orderedTypes.map((type) {
                  final isAlwaysShow = _alwaysShow.contains(type);
                  Color color = LogoHelper.getColor(type);
                  
                  return ListTile(
                    key: ValueKey(type),
                    leading: TransactionIcon(type: type, size: 24, color: color),
                    title: Text(
                      type,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                         Switch(
                          value: isAlwaysShow,
                          onChanged: (val) => _toggleAlwaysShow(type, val),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.drag_handle),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false), // Cancel
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saveSettings,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
