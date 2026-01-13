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
      final match = _tryMatchPattern(smsBody, pattern);
      if (match != null) {
        return match;
      }
    }

    return null; // No matching pattern found
  }

  /// Try to match SMS against a specific pattern
  Transaction? _tryMatchPattern(String smsBody, SmsPattern pattern) {
    try {
      final regex = RegExp(pattern.regexPattern, caseSensitive: false);
      final match = regex.firstMatch(smsBody);

      if (match == null) return null;

      // Extract fields based on mappings
      double? amount;
      String? sender;
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
            sender = value;
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

      return Transaction(
        type: pattern.transactionType,
        direction: pattern.direction,
        amount: amount!,
        sender: sender,
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
