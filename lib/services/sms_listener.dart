import 'package:telephony/telephony.dart';
import 'sms_parser.dart';
import '../database/database_helper.dart';

/// Background SMS listener service
class SmsListener {
  static final Telephony telephony = Telephony.instance;
  static final SmsParser _parser = SmsParser();
  static final DatabaseHelper _db = DatabaseHelper.instance;

  /// Initialize SMS listener
  static Future<bool> initialize() async {
    try {
      // Request SMS permissions
      final bool? permissionsGranted = await telephony.requestPhoneAndSmsPermissions;
      
      if (permissionsGranted != true) {
        return false;
      }

      // Set up background SMS handler
      telephony.listenIncomingSms(
        onNewMessage: _onSmsReceived,
        listenInBackground: true,
      );

      return true;
    } catch (e) {
      print('Error initializing SMS listener: $e');
      return false;
    }
  }

  /// Handler for incoming SMS messages
  static Future<void> _onSmsReceived(SmsMessage message) async {
    try {
      final smsBody = message.body ?? '';
      final sender = message.address ?? '';

      if (smsBody.isEmpty) return;

      // Try to parse the SMS
      final transaction = await _parser.parseSms(smsBody, sender);

      if (transaction != null) {
        // Save transaction to database
        await _db.createTransaction(transaction);
        
        // Update daily summary cache
        final summary = await _db.calculateDailySummary(DateTime.now());
        await _db.saveDailySummary(summary);

        print('Transaction detected and saved: ${transaction.type.name} - Tk ${transaction.amount}');
      }
    } catch (e) {
      print('Error processing SMS: $e');
    }
  }

  /// Get historical SMS messages (for initial import)
  static Future<List<SmsMessage>> getHistoricalSms({int days = 30}) async {
    try {
      final messages = await telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );

      // Filter to messages from last N days
      final cutoffDate = DateTime.now().subtract(Duration(days: days));
      return messages.where((msg) {
        final msgDate = DateTime.fromMillisecondsSinceEpoch(msg.date ?? 0);
        return msgDate.isAfter(cutoffDate);
      }).toList();
    } catch (e) {
      print('Error fetching historical SMS: $e');
      return [];
    }
  }

  /// Import historical SMS messages
  static Future<int> importHistoricalSms({int days = 30}) async {
    try {
      final messages = await getHistoricalSms(days: days);
      int importCount = 0;

      for (final message in messages) {
        final smsBody = message.body ?? '';
        final sender = message.address ?? '';
        
        if (smsBody.isEmpty) continue;

        final transaction = await _parser.parseSms(smsBody, sender);
        
        if (transaction != null) {
          // Use the SMS timestamp instead of current time
          final actualTimestamp = DateTime.fromMillisecondsSinceEpoch(message.date ?? 0);
          final txnWithCorrectTime = transaction.copyWith(timestamp: actualTimestamp);
          
          await _db.createTransaction(txnWithCorrectTime);
          importCount++;
        }
      }

      // Recalculate all daily summaries for imported period
      for (int i = 0; i < days; i++) {
        final date = DateTime.now().subtract(Duration(days: i));
        final summary = await _db.calculateDailySummary(date);
        if (summary.totalCount > 0) {
          await _db.saveDailySummary(summary);
        }
      }

      return importCount;
    } catch (e) {
      print('Error importing historical SMS: $e');
      return 0;
    }
  }
  /// Rescan and import transactions for a specific date
  static Future<int> rescanTransactionsForDate(DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
      
      final messages = await telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );

      int importCount = 0;

      for (final message in messages) {
        final msgDate = DateTime.fromMillisecondsSinceEpoch(message.date ?? 0);
        
        // Filter messages strictly within the date range
        if (msgDate.isBefore(startOfDay) || msgDate.isAfter(endOfDay)) {
          continue;
        }

        final smsBody = message.body ?? '';
        final sender = message.address ?? '';
        
        if (smsBody.isEmpty) continue;

        // Check for duplicates before parsing to save resources
        // Note: We check raw SMS content as unique identifier
        final exists = await _db.transactionExists(smsBody);
        if (exists) continue;

        final transaction = await _parser.parseSms(smsBody, sender);
        
        if (transaction != null) {
          // Use the actual SMS timestamp
          final txnWithCorrectTime = transaction.copyWith(timestamp: msgDate);
          
          await _db.createTransaction(txnWithCorrectTime);
          importCount++;
        }
      }

      if (importCount > 0) {
        // Recalculate daily summary for that date
        final summary = await _db.calculateDailySummary(startOfDay);
        await _db.saveDailySummary(summary);
      }

      return importCount;
    } catch (e) {
      print('Error rescanning transactions: $e');
      return 0;
    }
  }
}
