import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/transaction_service.dart';
import 'transactions_screen.dart';
import 'day_end_summary_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TransactionService _transactionService = TransactionService();
  Map<String, dynamic>? _todaySummary;
  List<Transaction> _recentTransactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final summary = await _transactionService.getTodaySummary();
      final transactions = await _transactionService.getTodayTransactions();
      
      setState(() {
        _todaySummary = summary;
        _recentTransactions = transactions.take(10).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Money Load Manager'),
        actions: [

          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              ).then((_) => _loadData());
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildTodayHeader(),
        const SizedBox(height: 20),
        _buildQuickStats(),
        const SizedBox(height: 24),
        _buildActionButtons(),
        const SizedBox(height: 24),
        _buildRecentTransactions(),
      ],
    );
  }

  Widget _buildTodayHeader() {
    final dateStr = DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());
    
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dateStr,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tk ${((_todaySummary?['totalAmount'] as num?) ?? 0).toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${(_todaySummary?['totalCount'] as int?) ?? 0} transactions today',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildQuickStats() {
    return Column(
      children: [
        // Direction cards
        Row(
          children: [
            Expanded(
              child: _buildDirectionCard(
                'Incoming',
                (_todaySummary?['incomingCount'] as int?) ?? 0,
                ((_todaySummary?['incomingAmount'] as num?) ?? 0).toDouble(),
                Icons.arrow_downward,
                Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDirectionCard(
                'Outgoing',
                (_todaySummary?['outgoingCount'] as int?) ?? 0,
                ((_todaySummary?['outgoingAmount'] as num?) ?? 0).toDouble(),
                Icons.arrow_upward,
                Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Type cards
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Flexiload',
                (_todaySummary?['flexiloadCount'] as int?) ?? 0,
                ((_todaySummary?['flexiloadAmount'] as num?) ?? 0).toDouble(),
                Icons.phone_android,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'bKash',
                (_todaySummary?['bkashCount'] as int?) ?? 0,
                ((_todaySummary?['bkashAmount'] as num?) ?? 0).toDouble(),
                Icons.account_balance_wallet,
                Colors.pink,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Bills',
                (_todaySummary?['utilityBillCount'] as int?) ?? 0,
                ((_todaySummary?['utilityBillAmount'] as num?) ?? 0).toDouble(),
                Icons.receipt_long,
                Colors.orange,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDirectionCard(String label, int count, double amount, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              count.toString(),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Tk ${amount.toStringAsFixed(0)}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, int count, double amount, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              count.toString(),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Tk ${amount.toStringAsFixed(0)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
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
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TransactionsScreen()),
              ).then((_) => _loadData());
            },
            icon: const Icon(Icons.list),
            label: const Text('All Transactions'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => DayEndSummaryScreen(date: DateTime.now())),
              );
            },
            icon: const Icon(Icons.summarize),
            label: const Text('Day Summary'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentTransactions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Transactions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_recentTransactions.isNotEmpty)
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const TransactionsScreen()),
                  ).then((_) => _loadData());
                },
                child: const Text('View All'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _recentTransactions.isEmpty
            ? Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.inbox,
                          size: 48,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No transactions today',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Transactions will appear here automatically\nwhen SMS messages are received',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _recentTransactions.length,
                itemBuilder: (context, index) {
                  final txn = _recentTransactions[index];
                  return _buildTransactionTile(txn);
                },
              ),
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
        title: Row(
          children: [
            Icon(
              txn.direction == TransactionDirection.incoming
                  ? Icons.arrow_downward
                  : Icons.arrow_upward,
              color: txn.direction == TransactionDirection.incoming
                  ? Colors.green
                  : Colors.red,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              'Tk ${txn.amount.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        subtitle: Text(
          '${txn.type.name} • ${DateFormat('h:mm a').format(txn.timestamp)}',
        ),
        trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.outline),
      ),
    );
  }
}
