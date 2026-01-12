import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/models.dart';
import '../services/transaction_service.dart';
import 'package:flutter/services.dart';
import 'transaction_detail_screen.dart';

class DayEndSummaryScreen extends StatefulWidget {
  final DateTime date;

  const DayEndSummaryScreen({super.key, required this.date});

  @override
  State<DayEndSummaryScreen> createState() => _DayEndSummaryScreenState();
}

class _DayEndSummaryScreenState extends State<DayEndSummaryScreen> {
  final TransactionService _transactionService = TransactionService();
  Map<String, dynamic>? _summary;
  List<Transaction> _transactions = [];
  bool _isLoading = true;
  bool _isRescanning = false;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.date;
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() => _isLoading = true);
    
    try {
      final summary = await _transactionService.getSummaryForDate(_selectedDate);
      
      // Load transaction list for the selected date
      final startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final endOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);
      
      final transactions = await _transactionService.getTransactions(
        startDate: startOfDay,
        endDate: endOfDay,
        // No pagination needed for a single day usually, but let's be safe if user has 1000s? 
        // User asked for "transactions list", probably all of them.
        limit: 1000, 
      );
      
      setState(() {
        _summary = summary;
        _transactions = transactions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading summary: $e')),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _loadSummary();
    }
  }

  Future<void> _exportSummary() async {
    if (_summary == null) return;

    try {
      final text = await _transactionService.exportSummaryToText(_selectedDate);
      
      await Clipboard.setData(ClipboardData(text: text));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Summary copied to clipboard')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting summary: $e')),
        );
      }
    }
  }

  Future<void> _rescan() async {
    setState(() => _isRescanning = true);

    try {
      // Use the selected date (or default to NOW if logic requires, but passed date is better)
      final count = await _transactionService.rescanForDate(_selectedDate);
      
      setState(() => _isRescanning = false);
      
      if (mounted) {
        if (count > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Rescan complete. Found $count new transactions.')),
          );
          _loadSummary(); // Refresh data
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Rescan complete. No new transactions found.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRescanning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error rescanning: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Day-End Summary'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDate,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _exportSummary,
          ),
          if (_isRescanning)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.sync),
              tooltip: 'Rescan SMS',
              onPressed: _rescan,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_summary == null || ((_summary!['totalCount'] as int?) ?? 0) == 0) {
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
              'No transactions on this date',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildDateHeader(),
        const SizedBox(height: 24),
        _buildTotalCard(),
        const SizedBox(height: 16),
        _buildDirectionCard(),
        const SizedBox(height: 24),
        _buildChart(),
        const SizedBox(height: 24),
        _buildBreakdown(),
        const SizedBox(height: 24),
        _buildTransactionList(),
      ],
    );
  }

  Widget _buildDateHeader() {
    final dateStr = DateFormat('EEEE, d MMMM yyyy').format(_selectedDate);
    
    return Text(
      dateStr,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.bold,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildTotalCard() {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              'Total Amount',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tk ${((_summary!['totalAmount'] as num?) ?? 0).toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${(_summary!['totalCount'] as int?) ?? 0} transactions',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDirectionCard() {
    final incomingAmount = ((_summary!['incomingAmount'] as num?) ?? 0).toDouble();
    final outgoingAmount = ((_summary!['outgoingAmount'] as num?) ?? 0).toDouble();
    final netBalance = incomingAmount - outgoingAmount;
    final isPositive = netBalance >= 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Money Flow',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Incoming
            Row(
              children: [
                Icon(Icons.arrow_downward, color: Colors.green, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Incoming',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${(_summary!['incomingCount'] as int?) ?? 0} transactions',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Tk ${((_summary!['incomingAmount'] as num?) ?? 0).toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Outgoing
            Row(
              children: [
                Icon(Icons.arrow_upward, color: Colors.red, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Outgoing',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${(_summary!['outgoingCount'] as int?) ?? 0} transactions',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Tk ${((_summary!['outgoingAmount'] as num?) ?? 0).toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            
            const Divider(height: 24),
            
            // Net Balance
            Row(
              children: [
                Icon(
                  isPositive ? Icons.trending_up : Icons.trending_down,
                  color: isPositive ? Colors.green : Colors.red,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Net Balance',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${netBalance >= 0 ? '+' : ''}${NumberFormat.currency(locale: 'en_IN', symbol: 'Tk ', decimalDigits: 2).format(netBalance)}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isPositive ? Colors.green : Colors.red,
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
    if (_summary == null || _summary!['typeBreakdown'] == null) {
      return {'count': 0, 'amount': 0.0, 'incomingAmount': 0.0, 'outgoingAmount': 0.0};
    }
    final breakdown = _summary!['typeBreakdown'] as Map<String, dynamic>;
    return (breakdown[type.name] as Map<String, dynamic>?) ?? 
           {'count': 0, 'amount': 0.0, 'incomingAmount': 0.0, 'outgoingAmount': 0.0};
  }

  Widget _buildChart() {
    final data = <_ChartData>[];
    for (final type in TransactionType.values) {
      if (type == TransactionType.other) continue; // Optional: exclude 'other' or keep it last
      
      final stats = _getTypeStats(type);
      if (((stats['amount'] as num?) ?? 0) > 0) {
        data.add(_ChartData(
          type.displayName,
          (stats['incomingAmount'] as num? ?? 0).toDouble(),
          (stats['outgoingAmount'] as num? ?? 0).toDouble(),
        ));
      }
    }
    
    // Add 'Other' at the end if it has data
    final otherStats = _getTypeStats(TransactionType.other);
    if (((otherStats['amount'] as num?) ?? 0) > 0) {
      data.add(_ChartData(
        TransactionType.other.displayName,
        (otherStats['incomingAmount'] as num? ?? 0).toDouble(),
        (otherStats['outgoingAmount'] as num? ?? 0).toDouble(),
      ));
    }

    if (data.isEmpty) return const SizedBox.shrink();
    
    // Find max value for Y-axis scaling
    double maxY = 0;
    for (var d in data) {
      if (d.incoming > maxY) maxY = d.incoming;
      if (d.outgoing > maxY) maxY = d.outgoing;
    }
    maxY = maxY == 0 ? 100 : maxY * 1.2;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Distribution (In & Out)',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 220, // Increased height for top titles
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      tooltipBgColor: Colors.blueGrey,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final type = rodIndex == 0 ? 'In' : 'Out';
                        return BarTooltipItem(
                          '$type: ${rod.toY.toStringAsFixed(0)}',
                          const TextStyle(color: Colors.white),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= data.length) return const Text('');
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              data[value.toInt()].label,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          // We can't easily map Y value back to specific bar here without complex logic
                          // So we rely on the BarChartGroupData logic or just hide it if too complex
                          // Actually, FlChart renders titles based on Y-axis. 
                          // TO SHOW VALUES ON TOP OF BARS, we need to use a different approach or 
                          // rely on tooltips. 
                          // However, user asked for "amount... explanation". 
                          // Let's use Tooltips for precision and maybe valid axis labels on Left.
                          return sideTitleWidgets(value, meta);
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: data.asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barsSpace: 4,
                      barRods: [
                        // Incoming Bar
                        BarChartRodData(
                          toY: entry.value.incoming,
                          color: Colors.green,
                          width: 16,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                        ),
                        // Outgoing Bar
                        BarChartRodData(
                          toY: entry.value.outgoing,
                          color: Colors.red,
                          width: 16,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Incoming', Colors.green),
                const SizedBox(width: 24),
                _buildLegendItem('Outgoing', Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget sideTitleWidgets(double value, TitleMeta meta) {
    if (value == meta.min || value == meta.max) return const SizedBox.shrink();
    return const SizedBox.shrink(); // Hide top axis titles, prefer tooltips/legend
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildBreakdown() {
    final breakdownItems = <Widget>[];
    
    // Process main types
    for (final type in TransactionType.values) {
      if (type == TransactionType.other) continue;
      
      final stats = _getTypeStats(type);
      breakdownItems.add(_buildBreakdownItem(
        type.displayName,
        (stats['count'] as int),
        (stats['incomingAmount'] as num? ?? 0).toDouble(),
        (stats['outgoingAmount'] as num? ?? 0).toDouble(),
        type.icon,
        type.color,
      ));
      breakdownItems.add(const Divider());
    }
    
    // Process Other type
    final otherStats = _getTypeStats(TransactionType.other);
    if (((otherStats['count'] as int?) ?? 0) > 0) {
      breakdownItems.add(_buildBreakdownItem(
        TransactionType.other.displayName,
        (otherStats['count'] as int),
        (otherStats['incomingAmount'] as num? ?? 0).toDouble(),
        (otherStats['outgoingAmount'] as num? ?? 0).toDouble(),
        TransactionType.other.icon,
        TransactionType.other.color,
      ));
    } else {
      // Remove last divider if added
      if (breakdownItems.isNotEmpty && breakdownItems.last is Divider) {
        breakdownItems.removeLast();
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Breakdown',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...breakdownItems,
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownItem(String label, int count, double incoming, double outgoing, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$count transactions',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (incoming > 0)
                Row(
                  children: [
                    Icon(Icons.arrow_downward, size: 12, color: Colors.green),
                    const SizedBox(width: 4),
                    Text(
                      NumberFormat.currency(locale: 'en_IN', symbol: 'Tk ', decimalDigits: 2).format(incoming),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              if (outgoing > 0)
                Row(
                  children: [
                    Icon(Icons.arrow_upward, size: 12, color: Colors.red),
                    const SizedBox(width: 4),
                    Text(
                      NumberFormat.currency(locale: 'en_IN', symbol: 'Tk ', decimalDigits: 2).format(outgoing),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.red, // Explicit red for outgoing
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              if (incoming == 0 && outgoing == 0)
                 Text(
                  'Tk 0.00',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildTransactionList() {
    if (_transactions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Transactions',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _transactions.length,
          itemBuilder: (context, index) {
            return _buildTransactionTile(_transactions[index]);
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
      case TransactionType.nagad:
        icon = Icons.account_balance_wallet;
        color = Colors.redAccent;
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
              _loadSummary(); // Refresh summary if transaction was deleted
            }
          });
        },
      ),
    );
  }


}

class _ChartData {
  final String label;
  final double incoming;
  final double outgoing;

  _ChartData(this.label, this.incoming, this.outgoing);
}
