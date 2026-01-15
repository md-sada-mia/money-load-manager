import 'package:another_telephony/telephony.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../models/models.dart';
import 'sms_parser.dart';
import '../database/database_helper.dart';
import 'contact_service.dart';

/// Background message handler for incoming SMS
/// This must be a top-level function for it to work in background
@pragma('vm:entry-point')
Future<void> backgroundMessageHandler(SmsMessage message) async {
  try {
    final smsBody = message.body ?? '';
    final sender = message.address ?? '';

    if (smsBody.isEmpty) return;

    // Check if we should process this sender
    if (!await SmsListener.shouldProcessSender(sender)) {
      print('Background: Sender $sender ignored by settings.');
      return;
    }

    // Initialize services
    final parser = SmsParser();
    final db = DatabaseHelper.instance;

    // Infer type from sender
    final inferredType = SmsListener.inferTypeFromSender(sender);

    // Try to parse the SMS
    // Pass inferred type to parser if needed, or update transaction after parsing
    Transaction? transaction = await parser.parseSms(smsBody, sender);

    if (transaction != null) {
      // Apply inferred type if available 
      if (inferredType != null) {
         transaction = transaction.copyWith(type: inferredType);
      }

      // Check for duplicates using smart logic
      final isDuplicate = await db.isDuplicateTransaction(transaction);
      
      if (!isDuplicate) {
        // Save transaction to database
        await db.createTransaction(transaction);
        print('Background: Transaction detected and saved: ${transaction.type} - Tk ${transaction.amount}');
      } else {
        print('Background: Duplicate transaction ignored: ${transaction.type} - Tk ${transaction.amount}');
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
  static final ContactService _contactService = ContactService();
  
  // Cache settings
  static bool? _saveUnknown;
  static bool? _saveKnown;

  static final StreamController<Transaction> _transactionStream = StreamController<Transaction>.broadcast();
  static Stream<Transaction> get transactionStream => _transactionStream.stream;

  /// Initialize SMS listener
  static Future<bool> initialize() async {
    try {
      await updateSettings();

      // Request SMS permissions using permission_handler
      if (!await Permission.sms.isGranted) {
        final status = await Permission.sms.request();
        if (!status.isGranted) {
          return false;
        }
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

  /// Update cached settings
  static Future<void> updateSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _saveUnknown = prefs.getBool('save_unknown_contacts') ?? false;
    _saveKnown = prefs.getBool('save_known_contacts') ?? false;
  }

  /// Check if we should process SMS from this sender
  /// Returns true if:
  /// 1. Sender is Alphanumeric (Business)
  /// 2. Sender is Unknown Numeric AND Save Unknown is ON
  /// 3. Sender is Known Contact AND Save Known is ON
  static Future<bool> shouldProcessSender(String sender) async {
    // 1. Check for Alphanumeric sender
    // Regex: Contains at least one letter, may contain digits/spaces. 
    // Generally alphanumeric senders don't look like phone numbers (11+ digits).
    // Simple check: if it contains letters, it's alphanumeric.
    final hasLetters = sender.contains(RegExp(r'[a-zA-Z]'));
    if (hasLetters) {
      return true; // Always process business matching
    }

    // Ensure settings are loaded
    if (_saveUnknown == null || _saveKnown == null) {
      await updateSettings();
    }

    // 2 & 3. Check contact status
    final isContact = await _contactService.isContactExists(sender);
    
    if (isContact) {
      return _saveKnown ?? false;
    } else {
      return _saveUnknown ?? false;
    }
  }

  /// Infer transaction type based on sender ID
  /// Simply returns the sender name as the type, or a normalized version.
  static String? inferTypeFromSender(String sender) {
    // If we want to group distinct sender IDs into a single "Type" name, we do it here.
    // e.g. "GP INFO" -> "Grameenphone"
    // For now, let's just return the Sender name (maybe Title Case or Uppercase?)
    // Or we can return null to let the Pattern decide. 
    // BUT the requirement is "avoid transaction type related manual", "auto decide type using sender info".
    // So if pattern says "Flexiload" but sender is "Grameenphone", we should probably prefer "Grameenphone".
    
    final s = sender.toLowerCase();
    
    if (s.contains('bkash')) return 'bKash';
    if (s.contains('nagad')) return 'Nagad';
    if (s.contains('rocket')) return 'Rocket';
    if (s.contains('upay')) return 'Upay';
    
    if (s.contains('desco')) return 'DESCO';
    if (s.contains('dpdc')) return 'DPDC';
    if (s.contains('wasa')) return 'WASA';
    if (s.contains('titas')) return 'Titas Gas';
    if (s.contains('bpdb')) return 'BPDB';
    
    // Telcos
    if (s.contains('gp') || s.contains('grameen')) return 'Grameenphone';
    if (s.contains('banglalink') || s.contains('bl')) return 'Banglalink';
    if (s.contains('robi')) return 'Robi';
    if (s.contains('airtel')) return 'Airtel';
    if (s.contains('teletalk')) return 'Teletalk';

    // If no specific mapping, just use the sender ID itself as the type?
    // User said "system automaticaly decide the transaction type. using sender info."
    // So yes, return the sender ID if nothing else matches?
    // But Alphanumeric senders are usually "BKASH", "GP INFO".
    // Let's return the sender itself if it's alphanumeric.
    if (sender.contains(RegExp(r'[a-zA-Z]'))) {
      return sender;
    }

    return null; // Fallback to pattern's type or generic
  }

  /// Handler for incoming SMS messages
  static Future<void> _onSmsReceived(SmsMessage message) async {
    try {
      final smsBody = message.body ?? '';
      final sender = message.address ?? '';

      if (smsBody.isEmpty) return;

      // Check filtering
      if (!await shouldProcessSender(sender)) {
        print('Sender $sender ignored by settings.');
        return;
      }

      // Try to parse the SMS
      Transaction? transaction = await _parser.parseSms(smsBody, sender);

      if (transaction != null) {
        // Infer type
        final inferredType = inferTypeFromSender(sender);
        if (inferredType != null) {
          // Verify if we should override. Generally yes, if it's a specific sender inference.
          transaction = transaction.copyWith(type: inferredType);
        } else if (sender.isEmpty == false) {
           // If no specific inference, but we have a sender, maybe use sender as type?
           // Only if original type is generic "Other" or "Unknown"?
           // Let's stick to inference or pattern for now to avoid messy types like "+88017..."
        }

        // Check for duplicates using smart logic
        final isDuplicate = await _db.isDuplicateTransaction(transaction);

        if (!isDuplicate) {
          // Save transaction to database
          await _db.createTransaction(transaction);

          print('Transaction detected and saved: ${transaction.type} - Tk ${transaction.amount}');
          _transactionStream.add(transaction);
        } else {
           print('Duplicate transaction ignored: ${transaction.type} - Tk ${transaction.amount}');
        }
      }
    } catch (e) {
      print('Error processing SMS: $e');
    }
  }



  /// Import historical SMS messages
  /// Fetches and processes SMS day-by-day to prevent OOM errors
  static Future<int> importHistoricalSms({
    int days = 30, 
    Function(double progress, String status)? onProgress,
  }) async {
    try {
      // 1. Check Permissions using permission_handler
      // We use permission_handler because another_telephony has a crash bug (Reply already submitted)
      // when requesting permissions if they are already handled or denied rapidly.
      if (!await Permission.sms.isGranted) {
        final status = await Permission.sms.request();
        if (!status.isGranted) {
           print('SMS permissions not granted for import');
           return 0;
        }
      }

      // 2. Ensure settings loaded & Pre-load contacts ONCE
      onProgress?.call(0.0, 'Preparing import...');
      await updateSettings();
      await _contactService.loadContacts();

      int totalImportCount = 0;
      const int batchSize = 20;
      final now = DateTime.now();

      // 3. Iterate day by day
      for (int d = 0; d < days; d++) {
        final progress = (d / days);
        onProgress?.call(progress, 'Scanning day ${d + 1} of $days...');
        
        // Calculate time range for this "day"
        // We go backwards from today? Or just iterate 0..days
        // d=0 => today. d=1 => yesterday.
        final date = now.subtract(Duration(days: d));
        
        // Start of day
        final startOfDay = DateTime(date.year, date.month, date.day);
        // End of day
        final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

        final startTimestamp = startOfDay.millisecondsSinceEpoch.toString();
        final endTimestamp = endOfDay.millisecondsSinceEpoch.toString();

        try {
          // Fetch SMS for THIS day only
          final messages = await telephony.getInboxSms(
            columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
            filter: SmsFilter.where(SmsColumn.DATE).greaterThanOrEqualTo(startTimestamp)
                      .and(SmsColumn.DATE).lessThanOrEqualTo(endTimestamp),
            sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
          );

          if (messages.isEmpty) continue;

          List<Transaction> batchTransactions = [];

          for (int i = 0; i < messages.length; i++) {
             // Yield to event loop occasionally to keep UI responsive
            if (i % batchSize == 0) {
              await Future.delayed(Duration.zero);
            }

            final message = messages[i];
            final smsBody = message.body ?? '';
            final sender = message.address ?? '';
            
            if (smsBody.isEmpty) continue;

            // Check filtering
            try {
               if (!await shouldProcessSender(sender)) continue;
            } catch (e) {
               continue; 
            }

            try {
              Transaction? transaction = await _parser.parseSms(smsBody, sender);
              
              if (transaction != null) {
                // Infer type
                final inferredType = inferTypeFromSender(sender);
                if (inferredType != null) {
                  transaction = transaction.copyWith(type: inferredType);
                }

                // Use the SMS timestamp
                final actualTimestamp = DateTime.fromMillisecondsSinceEpoch(message.date ?? 0);
                final txnWithCorrectTime = transaction.copyWith(
                  timestamp: actualTimestamp,
                );
                
                final isDuplicate = await _db.isDuplicateTransaction(txnWithCorrectTime);
                
                if (!isDuplicate) {
                   batchTransactions.add(txnWithCorrectTime);
                   totalImportCount++;
                }
              }
            } catch (e) {
              print('Error parsing message from $sender: $e');
            }

            // Commit batch within the day
            if (batchTransactions.length >= batchSize) {
              try {
                await _db.batchInsertTransactions(List.from(batchTransactions));
                batchTransactions.clear();
              } catch (e) {
                print('Error inserting batch: $e');
                batchTransactions.clear();
              }
            }
          }

          // Commit remaining for the day
          if (batchTransactions.isNotEmpty) {
              try {
                await _db.batchInsertTransactions(List.from(batchTransactions));
                batchTransactions.clear();
              } catch (e) {
                 print('Error inserting remaining batch: $e');
              }
          }

        } catch (e) {
          print('Error processing day $date: $e');
          // Continue to next day even if one day fails
        }
        
        // Small delay between days to let GC run if needed
        await Future.delayed(const Duration(milliseconds: 50));
      }
      
      onProgress?.call(1.0, 'Import complete!');
      return totalImportCount;
    } catch (e) {
      print('Error importing historical SMS: $e');
      return 0;
    }
  }
  /// Rescan and import transactions for a specific date
  static Future<int> rescanTransactionsForDate(DateTime date) async {
    try {
      // Check Permissions first
      if (!await Permission.sms.isGranted) {
        final status = await Permission.sms.request();
        if (!status.isGranted) {
           return 0;
        }
      }
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
      
      final startTimestamp = startOfDay.millisecondsSinceEpoch.toString();
      final endTimestamp = endOfDay.millisecondsSinceEpoch.toString();
      
      final messages = await telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        filter: SmsFilter.where(SmsColumn.DATE).greaterThanOrEqualTo(startTimestamp)
                  .and(SmsColumn.DATE).lessThanOrEqualTo(endTimestamp),
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );

      await updateSettings();
      await _contactService.loadContacts();

      int importCount = 0;
      List<Transaction> batchTransactions = [];
      const int batchSize = 20;

      for (int i = 0; i < messages.length; i++) {
        // Yield to event loop
        if (i % batchSize == 0) {
          await Future.delayed(Duration.zero);
        }

        final message = messages[i];
        final msgDate = DateTime.fromMillisecondsSinceEpoch(message.date ?? 0);
        
        // Date range already filtered by query

        final smsBody = message.body ?? '';
        final sender = message.address ?? '';
        
        if (smsBody.isEmpty) continue;

        // Check filtering
        try {
           if (!await shouldProcessSender(sender)) continue;
        } catch (e) {
           continue; 
        }

        try {
          // Parse first
          Transaction? transaction = await _parser.parseSms(smsBody, sender);
          
          if (transaction != null) {
            // Infer type
            final inferredType = inferTypeFromSender(sender);
            if (inferredType != null) {
              transaction = transaction.copyWith(type: inferredType);
            }

            // Use the actual SMS timestamp
            final txnWithCorrectTime = transaction.copyWith(timestamp: msgDate);
            
            // Check for duplicates using smart logic
            final isDuplicate = await _db.isDuplicateTransaction(txnWithCorrectTime);
            
            if (!isDuplicate) {
               batchTransactions.add(txnWithCorrectTime);
               importCount++;
            }
          }
        } catch (e) {
          print('Error parsing message from $sender: $e');
        }

        // Commit batch
        if (batchTransactions.length >= batchSize) {
          try {
            await _db.batchInsertTransactions(List.from(batchTransactions));
            batchTransactions.clear();
          } catch (e) {
            print('Error inserting batch: $e');
            batchTransactions.clear();
          }
        }
      }

      // Commit remaining
      if (batchTransactions.isNotEmpty) {
          try {
            await _db.batchInsertTransactions(List.from(batchTransactions));
          } catch (e) {
             print('Error inserting remaining batch: $e');
          }
      }

      return importCount;
    } catch (e) {
      print('Error rescanning transactions: $e');
      return 0;
    }
  }
}
