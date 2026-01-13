import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/transaction_service.dart';
import '../widgets/transaction_icon.dart';

class TransactionDetailScreen extends StatelessWidget {
  final Transaction transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildAmountCard(context),
          const SizedBox(height: 16),
          _buildDetailsCard(context),
          const SizedBox(height: 16),
          _buildSmsCard(context),
        ],
      ),
    );
  }

  Widget _buildAmountCard(BuildContext context) {
    Color color = transaction.type.color;

    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TransactionIcon(type: transaction.type, size: 48, color: color),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  transaction.direction == TransactionDirection.incoming
                      ? Icons.arrow_downward
                      : Icons.arrow_upward,
                  color: transaction.direction == TransactionDirection.incoming
                      ? Colors.green
                      : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  transaction.direction == TransactionDirection.incoming
                      ? 'INCOMING'
                      : 'OUTGOING',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: transaction.direction == TransactionDirection.incoming
                        ? Colors.green
                        : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Tk ${transaction.amount.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              transaction.type.name.toUpperCase(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Details',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow(context, 'Date', DateFormat('d MMMM yyyy').format(transaction.timestamp)),
            _buildDetailRow(context, 'Time', DateFormat('h:mm:ss a').format(transaction.timestamp)),
            if (transaction.smsTimestamp != null)
              _buildDetailRow(context, 'SMS Time', DateFormat('d MMM y HH:mm').format(transaction.smsTimestamp!)),
            const Divider(height: 24),
            if (transaction.txnId != null)
               _buildDetailRow(context, 'TrxID', transaction.txnId!), // Label 'TrxID' as requested/common
            if (transaction.reference != null)
              _buildDetailRow(context, 'Ref', transaction.reference!),
            if (transaction.sender != null)
              _buildDetailRow(context, 'Sender', transaction.sender!),
            if (transaction.recipient != null)
              _buildDetailRow(context, 'Recipient', transaction.recipient!),
            if (transaction.balance != null)
              _buildDetailRow(context, 'Balance', 'Tk ${NumberFormat('#,##0.00', 'en_IN').format(transaction.balance)}'),
             const Divider(height: 24),
            if (transaction.notes != null && transaction.notes!.isNotEmpty)
              _buildDetailRow(context, 'Notes', transaction.notes!),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmsCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Original SMS',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                transaction.rawSms,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: const Text('Are you sure you want to delete this transaction?'),
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

    if (confirmed == true && context.mounted) {
      try {
        await TransactionService().deleteTransaction(transaction);
        if (context.mounted) {
          Navigator.pop(context, true); // Return true to indicate deletion
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting transaction: $e')),
          );
        }
      }
    }
  }
}
