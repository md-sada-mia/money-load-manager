import '../models/models.dart';
import '../database/database_helper.dart';
import 'package:intl/intl.dart';
import 'sms_listener.dart';

/// Service for managing transactions
class TransactionService {
  final DatabaseHelper _db = DatabaseHelper.instance;

  /// Get all transactions
  Future<List<Transaction>> getAllTransactions() async {
    final result = await _db.getAllTransactions();
    return result;
  }

  /// Get transactions for a specific date
  Future<List<Transaction>> getTransactionsForDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
    final result = await _db.getTransactionsByDateRange(startOfDay, endOfDay);
    return result;
  }

  /// Get transactions for today
  Future<List<Transaction>> getTodayTransactions() async {
    return await getTransactionsForDate(DateTime.now());
  }

  /// Get transactions by type
  Future<List<Transaction>> getTransactionsByType(TransactionType type) async {
    final result = await _db.getTransactionsByType(type);
    return result;
  }

  /// Get transactions grouped by date
  Future<Map<String, List<Transaction>>> getTransactionsGroupedByDate() async {
    final transactions = await _db.getAllTransactions();
    final grouped = <String, List<Transaction>>{};

    for (final txn in transactions) {
      final dateKey = DateFormat('yyyy-MM-dd').format(txn.timestamp);
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(txn);
    }

    return grouped;
  }

  /// Get summary statistics for today
  Future<Map<String, dynamic>> getTodaySummary() async {
    return await getSummaryForDate(DateTime.now());
  }

  /// Get summary for a specific date
  /// Summaries are calculated on-the-fly from transaction records
  Future<Map<String, dynamic>> getSummaryForDate(DateTime date) async {
    return await _db.calculateDailySummary(date);
  }

  /// Create a new transaction manually
  Future<int> createTransaction(Transaction transaction) async {
    return await _db.createTransaction(transaction);
  }

  /// Update an existing transaction
  Future<void> updateTransaction(Transaction transaction) async {
    await _db.updateTransaction(transaction);
  }

  /// Delete a transaction
  Future<void> deleteTransaction(Transaction transaction) async {
    await _db.deleteTransaction(transaction.id!);
  }

  /// Export transactions to CSV format
  Future<String> exportToCsv({DateTime? startDate, DateTime? endDate}) async {
    final List<Transaction> transactions;
    
    if (startDate != null && endDate != null) {
      transactions = await _db.getTransactionsByDateRange(startDate, endDate);
    } else {
      transactions = await _db.getAllTransactions();
    }

    final buffer = StringBuffer();
    
    // CSV header
    buffer.writeln('Date,Time,Type,Amount,Sender,Recipient,Notes');
    
    // CSV rows
    for (final txn in transactions) {
      final date = DateFormat('yyyy-MM-dd').format(txn.timestamp);
      final time = DateFormat('HH:mm:ss').format(txn.timestamp);
      buffer.writeln([
        date,
        time,
        txn.type.name,
        txn.amount.toStringAsFixed(2),
        txn.sender ?? '',
        txn.recipient ?? '',
        txn.notes ?? '',
      ].join(','));
    }

    return buffer.toString();
  }

  /// Export summary to text format
  Future<String> exportSummaryToText(DateTime date) async {
    final summary = await getSummaryForDate(date);
    final dateStr = DateFormat('dd MMM yyyy').format(date);

    final buffer = StringBuffer();
    buffer.writeln('Daily Summary - $dateStr');
    buffer.writeln('=' * 40);
    buffer.writeln();
    buffer.writeln('Total Transactions: ${(summary['totalCount'] as int?) ?? 0}');
    buffer.writeln('Total Amount: Tk ${((summary['totalAmount'] as num?) ?? 0).toStringAsFixed(2)}');
    buffer.writeln();
    buffer.writeln('Breakdown:');
    buffer.writeln('-' * 40);
    buffer.writeln('Flexiload:');
    buffer.writeln('  Count: ${(summary['flexiloadCount'] as int?) ?? 0}');
    buffer.writeln('  Amount: Tk ${((summary['flexiloadAmount'] as num?) ?? 0).toStringAsFixed(2)}');
    buffer.writeln();
    buffer.writeln('bKash/Mobile Money:');
    buffer.writeln('  Count: ${(summary['bkashCount'] as int?) ?? 0}');
    buffer.writeln('  Amount: Tk ${((summary['bkashAmount'] as num?) ?? 0).toStringAsFixed(2)}');
    buffer.writeln();
    buffer.writeln('Utility Bills:');
    buffer.writeln('  Count: ${(summary['utilityBillCount'] as int?) ?? 0}');
    buffer.writeln('  Amount: Tk ${((summary['utilityBillAmount'] as num?) ?? 0).toStringAsFixed(2)}');
    buffer.writeln();
    buffer.writeln('Other:');
    buffer.writeln('  Count: ${(summary['otherCount'] as int?) ?? 0}');
    buffer.writeln('  Amount: Tk ${((summary['otherAmount'] as num?) ?? 0).toStringAsFixed(2)}');

    return buffer.toString();
  }

  /// Search transactions
  Future<List<Transaction>> searchTransactions(String query) async {
    final allTransactions = await _db.getAllTransactions();
    final lowerQuery = query.toLowerCase();

    final results = allTransactions.where((Transaction txn) {
      return txn.rawSms.toLowerCase().contains(lowerQuery) ||
             (txn.sender?.toLowerCase().contains(lowerQuery) ?? false) ||
             (txn.recipient?.toLowerCase().contains(lowerQuery) ?? false) ||
             txn.amount.toString().contains(lowerQuery);
    }).toList();
    
    return results;
  }
  /// Rescan SMS for a specific date
  Future<int> rescanForDate(DateTime date) async {
    // Import helper to avoid circular dependency issues if any
    // We already moved generic SMS logic to SmsListener
    return await SmsListener.rescanTransactionsForDate(date);
  }
}
