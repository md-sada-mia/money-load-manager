import 'package:another_telephony/telephony.dart';
import 'dart:async';
import '../models/models.dart';
import 'sms_parser.dart';
import '../database/database_helper.dart';

/// Background message handler for incoming SMS
/// This must be a top-level function for it to work in background
@pragma('vm:entry-point')
Future<void> backgroundMessageHandler(SmsMessage message) async {
  try {
    final smsBody = message.body ?? '';
    final sender = message.address ?? '';

    if (smsBody.isEmpty) return;

    // Initialize services
    final parser = SmsParser();
    final db = DatabaseHelper.instance;

    // Try to parse the SMS
    final transaction = await parser.parseSms(smsBody, sender);

    if (transaction != null) {
      // Check for duplicates using smart logic
      final isDuplicate = await db.isDuplicateTransaction(transaction);
      
      if (!isDuplicate) {
        // Save transaction to database
        await db.createTransaction(transaction);
        print('Background: Transaction detected and saved: ${transaction.type.name} - Tk ${transaction.amount}');
      } else {
        print('Background: Duplicate transaction ignored: ${transaction.type.name} - Tk ${transaction.amount}');
      }
    }
  } catch (e) {
    print('Background: Error processing SMS: $e');
  }
}

/// Background SMS listener service
class SmsListener {
  static final Telephony telephony = Telephony.instance;
  static final SmsParser _parser = SmsParser();
  static final DatabaseHelper _db = DatabaseHelper.instance;

  static final StreamController<Transaction> _transactionStream = StreamController<Transaction>.broadcast();
  static Stream<Transaction> get transactionStream => _transactionStream.stream;

  /// Initialize SMS listener
  static Future<bool> initialize() async {
    try {
      // Request SMS permissions
      final bool? permissionsGranted = await telephony.requestPhoneAndSmsPermissions;
      
      if (permissionsGranted != true) {
        return false;
      }

      // Set up foreground SMS handler
      telephony.listenIncomingSms(
        onNewMessage: _onSmsReceived,
        listenInBackground: false,
      );

      // Set up background SMS handler
      // This enables SMS processing even when app is in background
      telephony.listenIncomingSms(
        onNewMessage: _onSmsReceived,
        onBackgroundMessage: backgroundMessageHandler,
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
        // Check for duplicates using smart logic
        final isDuplicate = await _db.isDuplicateTransaction(transaction);

        if (!isDuplicate) {
          // Save transaction to database
          await _db.createTransaction(transaction);

          print('Transaction detected and saved: ${transaction.type.name} - Tk ${transaction.amount}');
          _transactionStream.add(transaction);
        } else {
           print('Duplicate transaction ignored: ${transaction.type.name} - Tk ${transaction.amount}');
        }
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
          
          // If the parsed transaction doesn't have an extracted timestamp, likely it should rely on the SMS metadata time 
          // or we preserve the extracted one if available.
          // The current `parseSms` sets `smsTimestamp` if found in text. 
          // `timestamp` in model is creation time, we should likely backdate it to the SMS time for historical imports.
          
          final txnWithCorrectTime = transaction.copyWith(
            timestamp: actualTimestamp,
          );
          
          final isDuplicate = await _db.isDuplicateTransaction(txnWithCorrectTime);
          
          if (!isDuplicate) {
             await _db.createTransaction(txnWithCorrectTime);
             importCount++;
          }
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

        // Parse first
        final transaction = await _parser.parseSms(smsBody, sender);
        
        if (transaction != null) {
          // Use the actual SMS timestamp
          final txnWithCorrectTime = transaction.copyWith(timestamp: msgDate);
          
          // Check for duplicates using smart logic
          final isDuplicate = await _db.isDuplicateTransaction(txnWithCorrectTime);
          
          if (!isDuplicate) {
             await _db.createTransaction(txnWithCorrectTime);
             importCount++;
          }
        }
      }

      return importCount;
    } catch (e) {
      print('Error rescanning transactions: $e');
      return 0;
    }
  }
}
