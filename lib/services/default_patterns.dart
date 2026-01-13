import '../models/models.dart';

/// Pre-configured SMS patterns for common Bangladesh financial services
class DefaultPatterns {
  static List<SmsPattern> getDefaultPatterns() {
    return [
      // bKash patterns
      SmsPattern(
        name: 'bKash Received',
        regexPattern: r'You have received Tk\.?\s*([\d,]+(?:\.\d{2})?)\s*from\s*(\d{11})',
        transactionType: TransactionType.bkash,
        direction: TransactionDirection.incoming,
        fieldMappings: {'amount': '1', 'sender': '2'},
      ),
      SmsPattern(
        name: 'bKash Sent',
        regexPattern: r'You have sent Tk\.?\s*([\d,]+(?:\.\d{2})?)\s*to\s*(\d{11})',
        transactionType: TransactionType.bkash,
        direction: TransactionDirection.outgoing,
        fieldMappings: {'amount': '1', 'recipient': '2'},
      ),
      SmsPattern(
        name: 'bKash Cash Out',
        regexPattern: r'Cash Out[:\s]+Tk\.?\s*([\d,]+(?:\.\d{2})?)',
        transactionType: TransactionType.bkash,
        direction: TransactionDirection.outgoing,
        fieldMappings: {'amount': '1'},
      ),
      SmsPattern(
        name: 'bKash Payment',
        regexPattern: r'Payment[:\s]+Tk\.?\s*([\d,]+(?:\.\d{2})?)',
        transactionType: TransactionType.bkash,
        direction: TransactionDirection.outgoing,
        fieldMappings: {'amount': '1'},
      ),

      // Flexiload patterns (agent receives payment for recharge)
      SmsPattern(
        name: 'Flexiload Success',
        regexPattern: r'Recharge successful\.?\s*Amount[:\s]*Tk\.?\s*([\d,]+(?:\.\d{2})?)',
        transactionType: TransactionType.flexiload,
        direction: TransactionDirection.incoming,
        fieldMappings: {'amount': '1'},
      ),
      SmsPattern(
        name: 'Flexiload Grameenphone',
        regexPattern: r'(\d+(?:\.\d{2})?)\s*Tk\.?\s*recharge\s*successful',
        transactionType: TransactionType.flexiload,
        direction: TransactionDirection.incoming,
        fieldMappings: {'amount': '1'},
      ),
      SmsPattern(
        name: 'Flexiload Banglalink',
        regexPattern: r'You have successfully recharged Tk\.?\s*(\d+(?:\.\d{2})?)',
        transactionType: TransactionType.flexiload,
        direction: TransactionDirection.incoming,
        fieldMappings: {'amount': '1'},
      ),
      SmsPattern(
        name: 'Flexiload Robi',
        regexPattern: r'Your account has been recharged with Tk\.?\s*(\d+(?:\.\d{2})?)',
        transactionType: TransactionType.flexiload,
        direction: TransactionDirection.incoming,
        fieldMappings: {'amount': '1'},
      ),

      // Nagad patterns
      SmsPattern(
        name: 'Nagad Received',
        regexPattern: r'Nagad.*received.*Tk\.?\s*(\d+(?:\.\d{2})?)',
        transactionType: TransactionType.bkash,
        direction: TransactionDirection.incoming,
        fieldMappings: {'amount': '1'},
      ),
      SmsPattern(
        name: 'Nagad Sent',
        regexPattern: r'Nagad.*sent.*Tk\.?\s*(\d+(?:\.\d{2})?)',
        transactionType: TransactionType.bkash,
        direction: TransactionDirection.outgoing,
        fieldMappings: {'amount': '1'},
      ),

      // Rocket patterns
      SmsPattern(
        name: 'Rocket Received',
        regexPattern: r'Rocket.*received.*Tk\.?\s*(\d+(?:\.\d{2})?)',
        transactionType: TransactionType.bkash,
        direction: TransactionDirection.incoming,
        fieldMappings: {'amount': '1'},
      ),

      // Utility bill patterns (agent receives payment for bill payment)
      SmsPattern(
        name: 'Bill Payment Success',
        regexPattern: r'Bill payment.*Tk\.?\s*(\d+(?:\.\d{2}))?\s*successful',
        transactionType: TransactionType.utilityBill,
        direction: TransactionDirection.incoming,
        fieldMappings: {'amount': '1'},
      ),
      SmsPattern(
        name: 'Electricity Bill',
        regexPattern: r'(?:DESCO|DPDC|BPDB).*Tk\.?\s*(\d+(?:\.\d{2})?)',
        transactionType: TransactionType.utilityBill,
        direction: TransactionDirection.incoming,
        fieldMappings: {'amount': '1'},
      ),
      SmsPattern(
        name: 'Water Bill',
        regexPattern: r'(?:WASA|DWASA).*Tk\.?\s*(\d+(?:\.\d{2})?)',
        transactionType: TransactionType.utilityBill,
        direction: TransactionDirection.incoming,
        fieldMappings: {'amount': '1'},
      ),
      SmsPattern(
        name: 'Gas Bill',
        regexPattern: r'(?:Titas|Gas).*bill.*Tk\.?\s*(\d+(?:\.\d{2})?)',
        transactionType: TransactionType.utilityBill,
        direction: TransactionDirection.incoming,
        fieldMappings: {'amount': '1'},
      ),
      SmsPattern(
        name: 'Nagad Money Received',
        regexPattern: r'Money\s+Received\.\s+Amount:\s+Tk\s+([\d,]+(?:\.\d{2})?)\s+Sender:\s+(\d+)\s+Ref:\s+(.*?)\s+TxnID:\s+(\w+)\s+Balance:\s+Tk\s+([\d,]+(?:\.\d{2})?)\s+(\d{2}/\d{2}/\d{4}\s+\d{2}:\d{2})',
        transactionType: TransactionType.nagad,
        direction: TransactionDirection.incoming,
        fieldMappings: {
          'amount': '1',
          'sender': '2',
          'reference': '3',
          'transactionId': '4',
          'balance': '5',
          'timestamp': '6',
        },
      )
    ];
  }
}
