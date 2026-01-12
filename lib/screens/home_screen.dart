import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/transaction_service.dart';
import 'transactions_screen.dart';
import 'transaction_detail_screen.dart';
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
              NumberFormat.currency(locale: 'en_IN', symbol: 'Tk ', decimalDigits: 2).format((_todaySummary?['totalAmount'] as num?) ?? 0),
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
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: TransactionType.values.map((type) {
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SizedBox(
                   width: 110, // Fixed width for consistent look
                   child: _buildDetailedStatCard(
                    type.displayName,
                    type,
                    type.icon,
                    type.color,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDirectionCard(String label, int count, double amount, IconData icon, Color color) {
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: 'Tk ', decimalDigits: 0);
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              currencyFormatter.format(amount),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '$count txns',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedStatCard(String label, TransactionType type, IconData icon, Color color) {
    final stats = _getTypeStats(type);
    final count = stats['count'] as int;
    final inAmount = stats['incomingAmount'] as double;
    final outAmount = stats['outgoingAmount'] as double;
    
    // Bangladesh standard formatting (e.g. 1,50,000)
    final numberFormatter = NumberFormat.decimalPattern('en_IN');
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header: Icon + Label
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (count > 0) ...[
                   const SizedBox(width: 4),
                   Text(
                     '($count)',
                     style: Theme.of(context).textTheme.bodySmall?.copyWith(
                       color: Theme.of(context).colorScheme.outline,
                     ),
                   )
                ]
              ],
            ),
            const SizedBox(height: 8),
            
            // Stats: In/Out vertically stacked
            // Incoming
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.arrow_downward, size: 12, color: Colors.green),
                const SizedBox(width: 4),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      numberFormatter.format(inAmount),
                      style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            // Outgoing
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.arrow_upward, size: 12, color: Colors.red),
                const SizedBox(width: 4),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      numberFormatter.format(outAmount),
                      style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _getTypeStats(TransactionType type) {
    if (_todaySummary == null || _todaySummary!['typeBreakdown'] == null) {
      return {'count': 0, 'amount': 0.0, 'incomingAmount': 0.0, 'outgoingAmount': 0.0};
    }
    final breakdown = _todaySummary!['typeBreakdown'] as Map<String, dynamic>;
    return (breakdown[type.name] as Map<String, dynamic>?) ?? 
           {'count': 0, 'amount': 0.0, 'incomingAmount': 0.0, 'outgoingAmount': 0.0};
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
    IconData icon = txn.type.icon;
    Color color = txn.type.color;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
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
              NumberFormat.currency(locale: 'en_IN', symbol: 'Tk ', decimalDigits: 2).format(txn.amount),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        subtitle: Text(
          '${txn.type.name} • ${DateFormat('h:mm a').format(txn.timestamp)}',
        ),
        trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.outline),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TransactionDetailScreen(transaction: txn),
            ),
          ).then((deleted) {
            if (deleted == true) {
              _loadData(); // Refresh dashboard if transaction was deleted
            }
          });
        },
      ),
    );

  }
}
