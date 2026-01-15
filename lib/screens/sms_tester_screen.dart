import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/sms_parser.dart';

class SmsTesterScreen extends StatefulWidget {
  const SmsTesterScreen({super.key});

  @override
  State<SmsTesterScreen> createState() => _SmsTesterScreenState();
}

class _SmsTesterScreenState extends State<SmsTesterScreen> {
  final _smsController = TextEditingController();
  final _parser = SmsParser();
  
  Transaction? _result;
  bool _hasTested = false;
  bool _isTesting = false;

  Future<void> _testSms() async {
    final sms = _smsController.text.trim();
    if (sms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please paste an SMS message first')),
      );
      return;
    }

    setState(() {
      _isTesting = true;
      _hasTested = true;
      _result = null;
    });

    try {
      // Use a dummy sender for testing
      final transaction = await _parser.parseSms(sms, 'TEST_SENDER');
      
      if (mounted) {
        setState(() {
          _result = transaction;
          _isTesting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isTesting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error testing SMS: $e')),
        );
      }
    }
  }

  void _clear() {
    setState(() {
      _smsController.clear();
      _result = null;
      _hasTested = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SMS Tester'),
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear',
            onPressed: _clear,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildInstructions(),
          const SizedBox(height: 24),
          _buildInput(),
          const SizedBox(height: 24),
          _buildTestButton(),
          if (_hasTested) ...[
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            _buildResult(),
          ],
        ],
      ),
    );
  }

  Widget _buildInstructions() {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.science, color: Theme.of(context).colorScheme.onPrimaryContainer),
                const SizedBox(width: 12),
                Text(
                  'Test Active Patterns',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Paste a raw SMS message below to check if it matches any of your currently active patterns. This does NOT save the transaction.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Raw SMS Content',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _smsController,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Paste SMS text here...',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () async {
              final data = await Clipboard.getData(Clipboard.kTextPlain);
              if (data?.text != null) {
                _smsController.text = data!.text!;
              }
            },
            icon: const Icon(Icons.paste),
            label: const Text('Paste from Clipboard'),
          ),
        ),
      ],
    );
  }

  Widget _buildTestButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _isTesting ? null : _testSms,
        icon: _isTesting 
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
          : const Icon(Icons.check_circle),
        label: const Text('Run Test'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildResult() {
    if (_result == null) {
      return Center(
        child: Column(
          children: [
            Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'No Match Found',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'The text did not match any active patterns.\nCheck your spacing, format, or pattern definitions.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Match Success!',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
            Icon(Icons.check_circle, color: Colors.green, size: 32),
          ],
        ),
        const SizedBox(height: 16),
        _buildResultRow('Direction', 
          _result!.direction == TransactionDirection.incoming 
            ? '📥 INCOMING' 
            : '📤 OUTGOING',
        ),
        _buildResultRow('Type', _result!.type.toUpperCase()),
        _buildResultRow('Amount', 'Tk ${_result!.amount.toStringAsFixed(2)}'),
        _buildResultRow('Sender', _result!.sender ?? 'N/A'),
        _buildResultRow('Recipient', _result!.recipient ?? 'N/A'),
        if (_result!.patternId != null)
           _buildResultRow('Pattern ID', _result!.patternId.toString()),
      ],
    );
  }

  Widget _buildResultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
