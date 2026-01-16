import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async'; // For StreamSubscription
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../models/models.dart';
import '../services/sms_listener.dart'; // For SmsListener
import 'transactions_screen.dart';
import 'transaction_detail_screen.dart';
import 'day_end_summary_screen.dart';
import 'settings_screen.dart';
import '../widgets/transaction_icon.dart';
import '../widgets/dashboard_config_dialog.dart';
import '../services/transaction_service.dart';
import '../services/sync_manager.dart';
import '../widgets/draggable_support_button.dart';
import '../utils/logo_helper.dart';
import 'help_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TransactionService _transactionService = TransactionService();
  final DatabaseHelper _db = DatabaseHelper.instance;
  Map<String, dynamic>? _todaySummary;
  List<Transaction> _recentTransactions = [];
  bool _isLoading = true;
  late StreamSubscription<Transaction> _transactionSubscription;
  
  // Customization state
  List<String> _orderedTypes = [];
  Set<String> _alwaysShow = {
    
  }; // Default important keys
  DateTimeRange _selectedDateRange = DateTimeRange(
    start: DateTime.now(),
    end: DateTime.now(),
  );

  @override
  void initState() {
    super.initState();
    // Initialize to today
    final now = DateTime.now();
    _selectedDateRange = DateTimeRange(
      start: DateTime(now.year, now.month, now.day),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
    
    _loadCustomizationSettings();
    _subscribeToTransactions();
    _subscribeToSync();
    _loadData();
  }
  
  Future<void> _loadCustomizationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load Order
    final orderStrings = prefs.getStringList('dashboard_card_order');
    if (orderStrings != null) {
      if (mounted) {
        setState(() {
          _orderedTypes = orderStrings;
        });
      }
    }

    // Load Always Show
    final alwaysShowStrings = prefs.getStringList('dashboard_always_show');
    if (alwaysShowStrings != null) {
      if (mounted) {
        setState(() {
          _alwaysShow = alwaysShowStrings.toSet();
        });
      }
    }
  }

  void _subscribeToTransactions() {
    _transactionSubscription = SmsListener.transactionStream.listen((transaction) {
      if (mounted) {
        _loadData();
      }
    });
  }

  // Listen for Sync updates
  late StreamSubscription<void> _syncSubscription;
  void _subscribeToSync() {
    _syncSubscription = SyncManager().onDataSynced.listen((_) {
      if (mounted) {
        _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dashboard updated from Sync')),
        );
      }
    });
  }

  @override
  void dispose() {
    _transactionSubscription.cancel();
    _syncSubscription.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final summary = await _transactionService.getSummaryForDateRange(
        _selectedDateRange.start, 
        _selectedDateRange.end
      );
      
      final transactions = await _transactionService.getTransactions(
        startDate: _selectedDateRange.start,
        endDate: _selectedDateRange.end,
        limit: 20
      );
      
      // Check for new types in summary that aren't in ordered types
      final breakdown = (summary['typeBreakdown'] as Map<String, dynamic>?) ?? {};
      final presentTypes = breakdown.keys.toList();
      bool orderChanged = false;
      
      for (final type in presentTypes) {
        if (!_orderedTypes.contains(type)) {
          _orderedTypes.add(type);
          orderChanged = true;
        }
      }
      
      // Check for new types in recent transactions too
      for (final txn in transactions) {
         if (!_orderedTypes.contains(txn.type)) {
           _orderedTypes.add(txn.type);
           orderChanged = true;
         }
      }

      if (orderChanged) {
        // Save updated order
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList('dashboard_card_order', _orderedTypes);
      }

      setState(() {
        _todaySummary = summary;
        _recentTransactions = transactions; // Already sorted by Service/DB usually DESC
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

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final startOfMonth = DateTime(now.year, now.month, 1);
    final startOfLastMonth = DateTime(now.year, now.month - 1, 1);
    final endOfLastMonth = DateTime(now.year, now.month, 0);

    final selectedOption = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Date Range'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'today'),
            child: const Text('Today'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'yesterday'),
            child: const Text('Yesterday'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'last_7'),
            child: const Text('Last 7 Days'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'last_30'),
            child: const Text('Last 30 Days'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'this_month'),
            child: const Text('This Month'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'last_month'),
            child: const Text('Last Month'),
          ),
          const Divider(),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'last_3_months'),
            child: const Text('Last 3 Months'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'last_6_months'),
            child: const Text('Last 6 Months'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'last_year'),
            child: const Text('Last 1 Year'),
          ),
          const Divider(),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'custom'),
            child: const Text('Custom Range...'),
          ),
        ],
      ),
    );

    if (selectedOption == null) return;

    DateTimeRange? newRange;

    switch (selectedOption) {
      case 'today':
        newRange = DateTimeRange(
          start: today,
          end: now, 
        );
        break;
      case 'yesterday':
        newRange = DateTimeRange(
          start: yesterday,
          end: yesterday.add(const Duration(hours: 23, minutes: 59, seconds: 59)),
        );
        break;
      case 'last_7':
        newRange = DateTimeRange(
          start: now.subtract(const Duration(days: 7)),
          end: now,
        );
        break;
      case 'last_30':
        newRange = DateTimeRange(
          start: now.subtract(const Duration(days: 30)),
          end: now,
        );
        break;
      case 'this_month':
        newRange = DateTimeRange(
          start: startOfMonth,
          end: now,
        );
        break;
      case 'last_month':
        newRange = DateTimeRange(
          start: startOfLastMonth,
          end: endOfLastMonth.add(const Duration(hours: 23, minutes: 59, seconds: 59)),
        );
        break;
       case 'last_3_months':
        newRange = DateTimeRange(
          start: now.subtract(const Duration(days: 90)),
          end: now,
        );
        break;
      case 'last_6_months':
        newRange = DateTimeRange(
          start: now.subtract(const Duration(days: 180)),
          end: now,
        );
        break;
      case 'last_year':
        newRange = DateTimeRange(
          start: now.subtract(const Duration(days: 365)),
          end: now,
        );
        break;
      case 'custom':
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          initialDateRange: _selectedDateRange,
        );
        if (picked != null) {
          newRange = DateTimeRange(
            start: picked.start,
            end: picked.end.add(const Duration(hours: 23, minutes: 59, seconds: 59)),
          );
        } else {
          return; 
        }
        break;
    }

    if (newRange != null && newRange != _selectedDateRange) {
      setState(() {
        _selectedDateRange = newRange!;
      });
      _loadData();
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/logo.png',
              height: 32,
              width: 32,
            ),
            const SizedBox(width: 10),
            const Text('Money Load Manager'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            tooltip: 'Select Date Range',
            onPressed: _selectDateRange,
          ),
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
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadData,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildDateHeader(),
                      const SizedBox(height: 20),
                      _buildQuickStats(),
                      const SizedBox(height: 24),
                      _buildActionButtons(),
                      const SizedBox(height: 24),
                      _buildRecentTransactions(),
                    ],
                  ),
          ),
           const DraggableSupportButton(),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildDateHeader(),
        const SizedBox(height: 20),
        _buildQuickStats(),
        const SizedBox(height: 24),
        _buildActionButtons(),
        const SizedBox(height: 24),
        _buildRecentTransactions(),
      ],
    );
  }

  Widget _buildDateHeader() {
    final startStr = DateFormat('MMM d').format(_selectedDateRange.start);
    final endStr = DateFormat('MMM d').format(_selectedDateRange.end);
    final isToday = DateUtils.isSameDay(_selectedDateRange.start, DateTime.now()) && 
                    DateUtils.isSameDay(_selectedDateRange.end, DateTime.now());
    
    // Check if single day selection
    final isSingleDay = DateUtils.isSameDay(_selectedDateRange.start, _selectedDateRange.end);
    String dateLabel = isSingleDay 
        ? DateFormat('EEEE, d MMMM yyyy').format(_selectedDateRange.start)
        : '$startStr - $endStr';

    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: InkWell(
        onTap: _selectDateRange,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        dateLabel,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (!isToday)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isSingleDay ? 'Past Date' : 'Custom Range',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.help_outline, color: Theme.of(context).colorScheme.onPrimaryContainer),
                    tooltip: 'Sync Help',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const HelpScreen()),
                      );
                    },
                  ),
                ],
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
                '${(_todaySummary?['totalCount'] as int?) ?? 0} transactions', // "today" removed
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
                ),
              ),
            ],
          ),
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
            children: _orderedTypes.map((type) {
              final stats = _getTypeStats(type);
              final count = stats['count'] as int;
              
              // Visibility Logic: 
              // Show if in "Always Show" set OR has transactions today.
              if (!_alwaysShow.contains(type) && count == 0) {
                return const SizedBox.shrink();
              }

              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onLongPress: _showCustomizationDialog,
                  child: SizedBox(
                     width: 110, // Fixed width for consistent look
                     child: _buildDetailedStatCard(
                      type, // Label is same as type usually
                      type,
                    ),
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

  Widget _buildDetailedStatCard(String label, String type) {
    final stats = _getTypeStats(type);
    final count = stats['count'] as int;
    final inAmount = stats['incomingAmount'] as double;
    final outAmount = stats['outgoingAmount'] as double;
    final color = LogoHelper.getColor(type);
    
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
                TransactionIcon(type: type, size: 18, color: color),
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

  Map<String, dynamic> _getTypeStats(String type) {
    if (_todaySummary == null || _todaySummary!['typeBreakdown'] == null) {
      return {'count': 0, 'amount': 0.0, 'incomingAmount': 0.0, 'outgoingAmount': 0.0};
    }
    final breakdown = _todaySummary!['typeBreakdown'] as Map<String, dynamic>;
    return (breakdown[type] as Map<String, dynamic>?) ?? 
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
    Color color = LogoHelper.getColor(txn.type);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: TransactionIcon(type: txn.type, color: color),
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
          '${txn.type} • ${DateFormat('h:mm a').format(txn.timestamp)}',
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

  Future<void> _showCustomizationDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => DashboardConfigDialog(
        currentOrder: _orderedTypes,
        alwaysShow: _alwaysShow,
      ),
    );

    if (result == true) {
      await _loadCustomizationSettings(); // Reload settings if changed
      setState(() {}); // Trigger rebuild
    }
  }
}
