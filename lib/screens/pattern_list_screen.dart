import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../database/database_helper.dart';
import '../utils/logo_helper.dart';
import '../widgets/transaction_icon.dart';

class PatternListScreen extends StatefulWidget {
  const PatternListScreen({super.key});

  @override
  State<PatternListScreen> createState() => _PatternListScreenState();
}

class _PatternListScreenState extends State<PatternListScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  List<SmsPattern> _patterns = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPatterns();
  }

  Future<void> _loadPatterns() async {
    setState(() => _isLoading = true);
    
    try {
      final patterns = await _db.getAllPatterns();
      setState(() {
        _patterns = patterns;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading patterns: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Patterns'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_patterns.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pattern,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No patterns saved yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create patterns in the Training Manager',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _patterns.length,
      itemBuilder: (context, index) {
        final pattern = _patterns[index];
        return _buildPatternCard(pattern);
      },
    );
  }

  Widget _buildPatternCard(SmsPattern pattern) {
    Color color = LogoHelper.getColor(pattern.transactionType ?? 'Unknown');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: TransactionIcon(type: pattern.transactionType ?? 'Unknown', size: 20, color: color),
        ),
        title: Text(
          pattern.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${pattern.transactionType} • Created ${DateFormat('d MMM yyyy').format(pattern.createdAt)}',
        ),
        trailing: Switch(
          value: pattern.isActive,
          onChanged: (value) => _togglePattern(pattern, value),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Regex Pattern',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    pattern.regexPattern,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _deletePattern(pattern),
                      icon: const Icon(Icons.delete),
                      label: const Text('Delete'),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _togglePattern(SmsPattern pattern, bool isActive) async {
    try {
      final updated = pattern.copyWith(isActive: isActive);
      await _db.updatePattern(updated);
      _loadPatterns();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating pattern: $e')),
        );
      }
    }
  }

  Future<void> _deletePattern(SmsPattern pattern) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Pattern'),
        content: Text('Are you sure you want to delete "${pattern.name}"?'),
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _db.deletePattern(pattern.id!);
        _loadPatterns();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pattern deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting pattern: $e')),
          );
        }
      }
    }
  }
}
