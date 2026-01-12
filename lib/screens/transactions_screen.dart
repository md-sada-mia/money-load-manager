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
  List<Transaction> _allTransactions = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _offset = 0;
  static const int _limit = 20;
  
  DateTimeRange? _dateRange;
  TransactionType? _filterType;
  TransactionDirection? _filterDirection;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Default to current month
    final now = DateTime.now();
    _dateRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
    );
    _scrollController.addListener(_onScroll);
    _loadTransactions(reset: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.9 &&
        !_isLoading &&
        _hasMore) {
      _loadTransactions();
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _dateRange,
    );

    if (picked != null && picked != _dateRange) {
      setState(() {
        _dateRange = DateTimeRange(
            start: picked.start,
            end: picked.end.add(const Duration(hours: 23, minutes: 59, seconds: 59))
        );
      });
      _loadTransactions(reset: true);
    }
  }

  Future<void> _loadTransactions({bool reset = false}) async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      if (reset) {
        _allTransactions = [];
        _groupedTransactions = {};
        _offset = 0;
        _hasMore = true;
      }
    });
    
    try {
      final transactions = await _transactionService.getTransactions(
        startDate: _dateRange?.start,
        endDate: _dateRange?.end,
        type: _filterType,
        direction: _filterDirection,
        limit: _limit,
        offset: _offset,
      );
      
      if (mounted) {
        setState(() {
           if (transactions.isEmpty) {
             _hasMore = false;
           } else {
             _allTransactions.addAll(transactions);
             _offset += transactions.length;
             // Update grouping
             _updateGrouping();
             
             if (transactions.length < _limit) {
               _hasMore = false;
             }
           }
           _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading transactions: $e')),
        );
      }
    }
  }

  void _updateGrouping() {
    final grouped = <String, List<Transaction>>{};
    for (final txn in _allTransactions) {
      final dateKey = DateFormat('yyyy-MM-dd').format(txn.timestamp);
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(txn);
    }
    _groupedTransactions = grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: 'Select Date Range',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter',
            onSelected: (value) {
              setState(() {
                if (value.startsWith('type_')) {
                  _filterType = value == 'type_all' 
                      ? null 
                      : TransactionType.values.firstWhere((t) => 'type_${t.name}' == value);
                  _filterDirection = null; // Reset direction filter when changing type
                } else if (value.startsWith('dir_')) {
                  _filterDirection = value == 'dir_all'
                      ? null
                      : TransactionDirection.values.firstWhere((d) => 'dir_${d.name}' == value);
                  _filterType = null; // Reset type filter when changing direction
                }
              });
              _loadTransactions(reset: true);
            },
            itemBuilder: (context) => [
              // ... existing items ...
              const PopupMenuItem(
                value: 'header_type',
                enabled: false,
                child: Text(
                  'Filter by Type',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const PopupMenuItem(
                value: 'type_all',
                child: Text('All Types'),
              ),
              const PopupMenuItem(
                value: 'type_flexiload',
                child: Text('Flexiload'),
              ),
              const PopupMenuItem(
                value: 'type_bkash',
                child: Text('bKash'),
              ),
              const PopupMenuItem(
                value: 'type_utilityBill',
                child: Text('Utility Bills'),
              ),
              const PopupMenuItem(
                value: 'type_nagad',
                child: Text('Nagad'),
              ),
              const PopupMenuItem(
                value: 'type_other',
                child: Text('Other'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'header_direction',
                enabled: false,
                child: Text(
                  'Filter by Direction',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const PopupMenuItem(
                value: 'dir_all',
                child: Text('All Directions'),
              ),
              const PopupMenuItem(
                value: 'dir_incoming',
                child: Row(
                  children: [
                    Icon(Icons.arrow_downward, color: Colors.green, size: 16),
                    SizedBox(width: 8),
                    Text('Incoming'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'dir_outgoing',
                child: Row(
                  children: [
                    Icon(Icons.arrow_upward, color: Colors.red, size: 16),
                    SizedBox(width: 8),
                    Text('Outgoing'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(30),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _dateRange != null 
                  ? '${DateFormat('MMM d').format(_dateRange!.start)} - ${DateFormat('MMM d').format(_dateRange!.end)}'
                  : 'All Time',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadTransactions(reset: true),
        child: _isLoading && _allTransactions.isEmpty
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
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: sortedKeys.length + 1, // +1 for loading indicator
      itemBuilder: (context, index) {
        if (index == sortedKeys.length) {
          return _hasMore
              ? const Center(child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ))
              : const SizedBox(height: 50); // Bottom padding
        }
        
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
                NumberFormat.currency(locale: 'en_IN', symbol: 'Tk ', decimalDigits: 2).format(totalAmount),
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
      case TransactionType.nagad:
        icon = Icons.account_balance_wallet;
        color = Colors.redAccent;
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
