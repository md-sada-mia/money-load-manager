import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/sms_parser.dart';
import '../database/database_helper.dart';
import 'pattern_list_screen.dart';

class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key});

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  final _smsController = TextEditingController();
  final _nameController = TextEditingController();
  final _patternController = TextEditingController();
  final DatabaseHelper _db = DatabaseHelper.instance;
  
  TransactionType _selectedType = TransactionType.flexiload;
  Map<int, String>? _extractedGroups;
  String? _testResult;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Training Manager'),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PatternListScreen()),
              );
            },
            icon: const Icon(Icons.list),
            label: const Text('View Patterns'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildInfoCard(),
          const SizedBox(height: 24),
          _buildSmsInput(),
          const SizedBox(height: 16),
          _buildPatternName(),
          const SizedBox(height: 16),
          _buildTypeSelector(),
          const SizedBox(height: 16),
          _buildPatternInput(),
          const SizedBox(height: 16),
          _buildExtractButton(),
          if (_extractedGroups != null) ...[
            const SizedBox(height: 16),
            _buildExtractedGroups(),
          ],
          if (_testResult != null) ...[
            const SizedBox(height: 16),
            _buildTestResult(),
          ],
          const SizedBox(height: 24),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  'How to Train',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '1. Paste a sample SMS message\n'
              '2. Create a regex pattern to match it\n'
              '3. Test the pattern\n'
              '4. Save for automatic detection',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmsInput() {
    return TextField(
      controller: _smsController,
      maxLines: 4,
      decoration: const InputDecoration(
        labelText: 'Sample SMS Message',
        hintText: 'Paste an SMS message here...',
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildPatternName() {
    return TextField(
      controller: _nameController,
      decoration: const InputDecoration(
        labelText: 'Pattern Name',
        hintText: 'e.g., "bKash Received"',
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Transaction Type',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        SegmentedButton<TransactionType>(
          segments: const [
            ButtonSegment(
              value: TransactionType.flexiload,
              label: Text('Flexiload'),
              icon: Icon(Icons.phone_android),
            ),
            ButtonSegment(
              value: TransactionType.bkash,
              label: Text('bKash'),
              icon: Icon(Icons.account_balance_wallet),
            ),
            ButtonSegment(
              value: TransactionType.utilityBill,
              label: Text('Bills'),
              icon: Icon(Icons.receipt_long),
            ),
            ButtonSegment(
              value: TransactionType.other,
              label: Text('Other'),
              icon: Icon(Icons.more_horiz),
            ),
          ],
          selected: {_selectedType},
          onSelectionChanged: (Set<TransactionType> newSelection) {
            setState(() {
              _selectedType = newSelection.first;
            });
          },
        ),
      ],
    );
  }

  Widget _buildPatternInput() {
    return TextField(
      controller: _patternController,
      maxLines: 3,
      decoration: const InputDecoration(
        labelText: 'Regex Pattern',
        hintText: r'e.g., You have received Tk\.?\s*(\d+(?:\.\d{2})?)',
        border: OutlineInputBorder(),
        helperText: 'Use parentheses () to capture amount, sender, etc.',
      ),
    );
  }

  Widget _buildExtractButton() {
    return ElevatedButton.icon(
      onPressed: _extractGroups,
      icon: const Icon(Icons.search),
      label: const Text('Test Pattern'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildExtractedGroups() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Captured Groups',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ..._extractedGroups!.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Group ${entry.key}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
            Text(
              'Group 1 will be treated as "amount".\n'
              'Group 2 can be "sender" or "recipient".',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestResult() {
    final isSuccess = _testResult == 'Match!';
    
    return Card(
      color: isSuccess 
          ? Colors.green.withOpacity(0.1) 
          : Colors.red.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error,
              color: isSuccess ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _testResult!,
                style: TextStyle(
                  color: isSuccess ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _reset,
            child: const Text('Reset'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            onPressed: _savePattern,
            child: const Text('Save Pattern'),
          ),
        ),
        const SizedBox(width: 12),
        if (_extractedGroups != null)
        Expanded(
          child: FilledButton.tonal(
            onPressed: _copyCode,
            child: const Text('Copy Code'),
          ),
        ),
      ],
    );
  }

  void _extractGroups() {
    final sms = _smsController.text.trim();
    final pattern = _patternController.text.trim();

    if (sms.isEmpty || pattern.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both SMS and pattern')),
      );
      return;
    }

    final groups = SmsParser.extractGroups(sms, pattern);
    
    setState(() {
      _extractedGroups = groups;
      _testResult = groups != null ? 'Match!' : 'No match found';
    });
  }

  void _reset() {
    setState(() {
      _smsController.clear();
      _nameController.clear();
      _patternController.clear();
      _extractedGroups = null;
      _testResult = null;
    });
  }

  Future<void> _savePattern() async {
    final name = _nameController.text.trim();
    final pattern = _patternController.text.trim();

    if (name.isEmpty || pattern.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter pattern name and regex')),
      );
      return;
    }

    try {
      // Create basic field mappings
      final fieldMappings = <String, String>{
        'amount': '1', // First group is always amount
      };
      if (_extractedGroups != null && _extractedGroups!.length > 1) {
        fieldMappings['sender'] = '2'; // Second group could be sender/recipient
      }

      final smsPattern = SmsPattern(
        name: name,
        regexPattern: pattern,
        transactionType: _selectedType,
        fieldMappings: fieldMappings,
      );

      await _db.createPattern(smsPattern);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pattern saved successfully')),
        );
        _reset();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving pattern: $e')),
        );
      }
    }
  }

  void _copyCode() {
    final name = _nameController.text.trim();
    final pattern = _patternController.text.trim();
    
    // Create mapping string
    final mappingBuffer = StringBuffer();
    if (_extractedGroups != null) {
      mappingBuffer.write("{'amount': '1'");
      if (_extractedGroups!.length > 1) {
        mappingBuffer.write(", 'sender': '2'");
      }
      mappingBuffer.write("}");
    } else {
       mappingBuffer.write("{'amount': '1'}");
    }

    final code = '''
      SmsPattern(
        name: '$name',
        regexPattern: r'$pattern',
        transactionType: ${_selectedType.toString()},
        fieldMappings: ${mappingBuffer.toString()},
      ),''';

    Clipboard.setData(ClipboardData(text: code));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dart code copied to clipboard')),
      );
    }
  }

  @override
  void dispose() {
    _smsController.dispose();
    _nameController.dispose();
    _patternController.dispose();
    super.dispose();
  }
}
