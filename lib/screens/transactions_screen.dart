import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/transaction_service.dart';
import 'transaction_detail_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final TransactionService _transactionService = TransactionService();
  Map<String, List<Transaction>> _groupedTransactions = {};
  bool _isLoading = true;
  TransactionType? _filterType;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _isLoading = true);
    
    try {
      Map<String, List<Transaction>> grouped;
      
      if (_filterType != null) {
        final transactions = await _transactionService.getTransactionsByType(_filterType!);
        grouped = {};
        for (final txn in transactions) {
          final dateKey = DateFormat('yyyy-MM-dd').format(txn.timestamp);
          if (!grouped.containsKey(dateKey)) {
            grouped[dateKey] = [];
          }
          grouped[dateKey]!.add(txn);
        }
      } else {
        grouped = await _transactionService.getTransactionsGroupedByDate();
      }
      
      setState(() {
        _groupedTransactions = grouped;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading transactions: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Transactions'),
        actions: [
          PopupMenuButton<TransactionType?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (type) {
              setState(() => _filterType = type);
              _loadTransactions();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('All Types'),
              ),
              const PopupMenuItem(
                value: TransactionType.flexiload,
                child: Text('Flexiload'),
              ),
              const PopupMenuItem(
                value: TransactionType.bkash,
                child: Text('bKash'),
              ),
              const PopupMenuItem(
                value: TransactionType.utilityBill,
                child: Text('Utility Bills'),
              ),
              const PopupMenuItem(
                value: TransactionType.other,
                child: Text('Other'),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadTransactions,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_groupedTransactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No transactions found',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    final sortedKeys = _groupedTransactions.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedKeys.length,
      itemBuilder: (context, index) {
        final dateKey = sortedKeys[index];
        final transactions = _groupedTransactions[dateKey]!;
        final date = DateTime.parse(dateKey);
        
        return _buildDateGroup(date, transactions);
      },
    );
  }

  Widget _buildDateGroup(DateTime date, List<Transaction> transactions) {
    final isToday = _isToday(date);
    final isYesterday = _isYesterday(date);
    
    String dateLabel;
    if (isToday) {
      dateLabel = 'Today';
    } else if (isYesterday) {
      dateLabel = 'Yesterday';
    } else {
      dateLabel = DateFormat('EEEE, d MMMM yyyy').format(date);
    }

    final totalAmount = transactions.fold<double>(0, (sum, txn) => sum + txn.amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dateLabel,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Tk ${totalAmount.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        ...transactions.map((txn) => _buildTransactionTile(txn)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildTransactionTile(Transaction txn) {
    IconData icon;
    Color color;
    
    switch (txn.type) {
      case TransactionType.flexiload:
        icon = Icons.phone_android;
        color = Colors.blue;
        break;
      case TransactionType.bkash:
        icon = Icons.account_balance_wallet;
        color = Colors.pink;
        break;
      case TransactionType.utilityBill:
        icon = Icons.receipt_long;
        color = Colors.orange;
        break;
      case TransactionType.other:
        icon = Icons.more_horiz;
        color = Colors.grey;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(
          'Tk ${txn.amount.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${txn.type.name} • ${DateFormat('h:mm a').format(txn.timestamp)}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TransactionDetailScreen(transaction: txn),
            ),
          ).then((deleted) {
            if (deleted == true) {
              _loadTransactions();
            }
          });
        },
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  bool _isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day;
  }
}
