import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/models.dart';
import '../services/transaction_service.dart';
import 'package:flutter/services.dart';

class DayEndSummaryScreen extends StatefulWidget {
  final DateTime date;

  const DayEndSummaryScreen({super.key, required this.date});

  @override
  State<DayEndSummaryScreen> createState() => _DayEndSummaryScreenState();
}

class _DayEndSummaryScreenState extends State<DayEndSummaryScreen> {
  final TransactionService _transactionService = TransactionService();
  Map<String, dynamic>? _summary;
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
      setState(() {
        _summary = summary;
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
    final flexiloadStats = _getTypeStats(TransactionType.flexiload);
    final bkashStats = _getTypeStats(TransactionType.bkash);
    final billStats = _getTypeStats(TransactionType.utilityBill);
    final otherStats = _getTypeStats(TransactionType.other);

    final data = [
      if (((flexiloadStats['amount'] as num?) ?? 0) > 0)
        _ChartData('Flexiload', (flexiloadStats['amount'] as num).toDouble(), Colors.blue),
      if (((bkashStats['amount'] as num?) ?? 0) > 0)
        _ChartData('bKash', (bkashStats['amount'] as num).toDouble(), Colors.pink),
      if (((billStats['amount'] as num?) ?? 0) > 0)
        _ChartData('Bills', (billStats['amount'] as num).toDouble(), Colors.orange),
      if (((otherStats['amount'] as num?) ?? 0) > 0)
        _ChartData('Other', (otherStats['amount'] as num).toDouble(), Colors.grey),
    ];

    if (data.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Distribution',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: ((_summary!['totalAmount'] as num?) ?? 0).toDouble() * 1.2,
                  barTouchData: BarTouchData(enabled: false),
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
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
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
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.amount,
                          color: entry.value.color,
                          width: 40,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdown() {
    final flexiloadStats = _getTypeStats(TransactionType.flexiload);
    final bkashStats = _getTypeStats(TransactionType.bkash);
    final billStats = _getTypeStats(TransactionType.utilityBill);
    final otherStats = _getTypeStats(TransactionType.other);

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
            _buildBreakdownItem(
              'Flexiload',
              (flexiloadStats['count'] as int),
              (flexiloadStats['amount'] as num).toDouble(),
              Icons.phone_android,
              Colors.blue,
            ),
            const Divider(),
            _buildBreakdownItem(
              'bKash / Mobile Money',
              (bkashStats['count'] as int),
              (bkashStats['amount'] as num).toDouble(),
              Icons.account_balance_wallet,
              Colors.pink,
            ),
            const Divider(),
            _buildBreakdownItem(
              'Utility Bills',
              (billStats['count'] as int),
              (billStats['amount'] as num).toDouble(),
              Icons.receipt_long,
              Colors.orange,
            ),
            if (((otherStats['count'] as int?) ?? 0) > 0) ...[
              const Divider(),
              _buildBreakdownItem(
                'Other',
                (otherStats['count'] as int),
                (otherStats['amount'] as num).toDouble(),

                Icons.more_horiz,
                Colors.grey,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBreakdownItem(String label, int count, double amount, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium,
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
          Text(
            NumberFormat.currency(locale: 'en_IN', symbol: 'Tk ', decimalDigits: 2).format(amount),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartData {
  final String label;
  final double amount;
  final Color color;

  _ChartData(this.label, this.amount, this.color);
}
