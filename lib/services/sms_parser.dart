import '../models/models.dart';
import '../database/database_helper.dart';
import 'default_patterns.dart';

/// SMS parser that matches incoming messages against patterns
class SmsParser {
  final DatabaseHelper _db = DatabaseHelper.instance;

  /// Parse an SMS message and extract transaction data
  /// Checks default patterns first, then user-created patterns from database
  Future<Transaction?> parseSms(String smsBody, String sender) async {
    // First, check default patterns from code
    final defaultPatterns = DefaultPatterns.getDefaultPatterns();
    
    // Then, get user-created patterns from database
    final customPatterns = await _db.getActivePatterns();
    
    // Combine: default patterns first, then custom patterns
    final allPatterns = [...defaultPatterns, ...customPatterns];

    for (final pattern in allPatterns) {
      final match = _tryMatchPattern(smsBody, pattern, sender);
      if (match != null) {
        return match;
      }
    }

    return null; // No matching pattern found
  }

  /// Try to match SMS against a specific pattern
  Transaction? _tryMatchPattern(String smsBody, SmsPattern pattern, String smsSender) {
    try {
      final regex = RegExp(pattern.regexPattern, caseSensitive: false);
      final match = regex.firstMatch(smsBody);

      if (match == null) return null;

      // Extract fields based on mappings
      double? amount;
      String? extractedSender; // Renamed from sender to avoid confusion
      String? recipient;
      String? reference;
      String? txnId;
      double? balance;
      DateTime? smsTimestamp;

      pattern.fieldMappings.forEach((field, groupIndex) {
        final groupNum = int.tryParse(groupIndex);
        if (groupNum == null || groupNum > match.groupCount) return;

        final value = match.group(groupNum);
        if (value == null) return;

        switch (field) {
          case 'amount':
            amount = double.tryParse(value.replaceAll(',', ''));
            break;
          case 'sender':
            extractedSender = value;
            break;
          case 'recipient':
            recipient = value;
            break;
          case 'reference':
            reference = value;
            break;
          case 'transactionId':
            txnId = value;
            break;
          case 'balance':
            balance = double.tryParse(value.replaceAll(',', ''));
            break;
          case 'timestamp':
            try {
              // Expecting format dd/MM/yyyy HH:mm
              // This is a basic parser for the format seen in default_patterns.dart
              // Adjust pattern matching logic if format varies significantly
              final parts = value.split(' ');
              if (parts.length >= 2) {
                final dateParts = parts[0].split('/');
                final timeParts = parts[1].split(':');
                if (dateParts.length == 3 && timeParts.length == 2) {
                  smsTimestamp = DateTime(
                    int.parse(dateParts[2]), // year
                    int.parse(dateParts[1]), // month
                    int.parse(dateParts[0]), // day
                    int.parse(timeParts[0]), // hour
                    int.parse(timeParts[1]), // minute
                  );
                }
              }
            } catch (e) {
              // Ignore parsing errors for timestamp
              print('Error parsing timestamp: $e');
            }
            break;
        }
      });

      // Amount is required for a valid transaction
      if (amount == null || amount! <= 0) return null;

      // Determine Type:
      // 1. If pattern has a specific type override, use it.
      // 2. Otherwise try to infer from the SMS SENDER Address (not extracted body sender).
      // 3. Fallback to "Unknown"
      String finalType = pattern.transactionType ?? 'Unknown';
      
      // If pattern type is not set, try to infer from sender
      if (pattern.transactionType == null) {
        // Use the SMS SENDER ADDRESS for inference
        // This is usually more reliable for type detection (e.g. "bKash", "GP INFO")
        final s = smsSender.toLowerCase();
        
        if (s.contains('bkash')) finalType = 'bKash';
        else if (s.contains('nagad')) finalType = 'Nagad';
        else if (s.contains('rocket')) finalType = 'Rocket';
        else if (s.contains('upay')) finalType = 'Upay';
        else if (s.contains('desco')) finalType = 'DESCO';
        else if (s.contains('dpdc')) finalType = 'DPDC';
        else if (s.contains('wasa')) finalType = 'WASA';
        else if (s.contains('titas')) finalType = 'Titas Gas';
        else if (s.contains('bpdb')) finalType = 'BPDB';
        // Telcos
        else if (s.contains('gp') || s.contains('grameen')) finalType = 'Grameenphone';
        else if (s.contains('banglalink') || s.contains('bl')) finalType = 'Banglalink';
        else if (s.contains('robi')) finalType = 'Robi';
        else if (s.contains('airtel')) finalType = 'Airtel';
        else if (s.contains('teletalk')) finalType = 'Teletalk';
        // If extracted sender from body exists, maybe that's a clue? 
        // But usually body contains the person who sent money, not the service type.
        else if (smsSender.isNotEmpty) finalType = smsSender; // Fallback to SMS Sender ID
      }

      return Transaction(
        type: finalType,
        direction: pattern.direction,
        amount: amount!,
        sender: extractedSender,
        recipient: recipient,
        timestamp: DateTime.now(), // Record creation time
        rawSms: smsBody,
        patternId: pattern.id,
        reference: reference,
        txnId: txnId,
        balance: balance,
        smsTimestamp: smsTimestamp, // Extracted timestamp from SMS
      );
    } catch (e) {
      // Invalid regex or parsing error, skip this pattern
      return null;
    }
  }

  /// Test if a pattern matches an SMS (used in training UI)
  static bool testPattern(String smsBody, String regexPattern) {
    try {
      final regex = RegExp(regexPattern, caseSensitive: false);
      return regex.hasMatch(smsBody);
    } catch (e) {
      return false;
    }
  }

  /// Extract capture groups from a pattern match (used in training UI)
  static Map<int, String>? extractGroups(String smsBody, String regexPattern) {
    try {
      final regex = RegExp(regexPattern, caseSensitive: false);
      final match = regex.firstMatch(smsBody);
      
      if (match == null) return null;

      final groups = <int, String>{};
      for (int i = 1; i <= match.groupCount; i++) {
        final value = match.group(i);
        if (value != null) {
          groups[i] = value;
        }
      }
      return groups;
    } catch (e) {
      return null;
    }
  }
}
