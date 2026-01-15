import '../models/models.dart';

/// Pre-configured SMS patterns for common Bangladesh financial services
class DefaultPatterns {
  static List<SmsPattern> getDefaultPatterns() {
    return [
      // bKash patterns
      SmsPattern(
        name: 'bKash Received',
        regexPattern: r'You\s+have\s+received\s+Tk\s*([\d,]+(?:\.\d{2})?)\s+from\s+(\d+)\.\s+Ref\s+(.*?)\.\s+Fee\s+Tk\s*([\d,]+(?:\.\d{2})?)\.\s+Balance\s+Tk\s*([\d,]+(?:\.\d{2})?)\.\s+TrxID\s+(\w+)\s+at\s+(\d{2}/\d{2}/\d{4}\s+\d{2}:\d{2})',
        direction: TransactionDirection.incoming,
        fieldMappings: {
          'amount': '1',
          'sender': '2',
          'reference': '3',
          'fee': '4',
          'balance': '5',
          'transactionId': '6',
          'timestamp': '7',
        },
      ),
      SmsPattern(
        name: 'Nagad Money Received',
        regexPattern: r'Money\s+Received\.\s+Amount:\s+Tk\s+([\d,]+(?:\.\d{2})?)\s+Sender:\s+(\d+)\s+Ref:\s+(.*?)\s+TxnID:\s+(\w+)\s+Balance:\s+Tk\s+([\d,]+(?:\.\d{2})?)\s+(\d{2}/\d{2}/\d{4}\s+\d{2}:\d{2})',
        direction: TransactionDirection.incoming,
        fieldMappings: {
          'amount': '1',
          'sender': '2',
          'reference': '3',
          'transactionId': '4',
          'balance': '5',
          'timestamp': '6',
        },
      ),
      SmsPattern(
        name: 'Cash In Successful',
        direction: TransactionDirection.outgoing,
        regexPattern: r'Cash In Successful\.\s+Amount:\s*Tk\s*([\d,]+(?:\.\d{2})?)\s+Customer:\s*([\d\*]+)\s+TxnID:\s*(\w+)\s+Comm:\s*Tk\s*[\d,]+(?:\.\d{2})?\s+Balance:\s*Tk\s*([\d,]+(?:\.\d{2})?)\s+(\d{2}/\d{2}/\d{4}\s\d{2}:\d{2})',
        fieldMappings: {
          'amount': '1',
          'recipient': '2',
          'transactionId': '3',
          'balance': '4',
          'timestamp': '5',
        },
      ),
      SmsPattern(
        name: 'Cash Out Received',
        direction: TransactionDirection.incoming,
        regexPattern: r'Cash Out Received\.\s+Amount:\s*Tk\s*([\d,]+(?:\.\d{2})?)\s+Customer:\s*([\d\*]+)\s+TxnID:\s*(\w+)\s+Comm:\s*Tk\s*[\d,]+(?:\.\d{2})?\s+Balance:\s*Tk\s*([\d,]+(?:\.\d{2})?)\s+(\d{2}/\d{2}/\d{4}\s\d{2}:\d{2})',
        fieldMappings: {
          'amount': '1',
          'sender': '2',
          'transactionId': '3',
          'balance': '4',
          'timestamp': '5',
        },
      ),
      SmsPattern(
        name: 'B2B Received',
        direction: TransactionDirection.incoming,
        regexPattern: r'B2B Received\.\s+Amount:\s*Tk\s*([\d,]+(?:\.\d{2})?)\s+Sender:\s*([\d\*]+)\s+TxnID:\s*(\w+)\s+Balance:\s*Tk\s*([\d,]+(?:\.\d{2})?)\s+(\d{2}/\d{2}/\d{4}\s\d{2}:\d{2})',
        fieldMappings: {
          'amount': '1',
          'sender': '2',
          'transactionId': '3',
          'balance': '4',
          'timestamp': '5',
        },
      ),
      SmsPattern(
        name: 'Payment Successful',
        direction: TransactionDirection.outgoing,
        regexPattern: r"Payment to '(.*?)' is Successful\.\s+Amount:\s*Tk\s*([\d,]+(?:\.\d{2})?)\s+TxnID:\s*(\w+)\s+Balance:\s*Tk\s*([\d,]+(?:\.\d{2})?)\s+(\d{2}/\d{2}/\d{4}\s\d{2}:\d{2})",
        fieldMappings: {
          'recipient': '1',
          'amount': '2',
          'transactionId': '3',
          'balance': '4',
          'timestamp': '5',
        },
      ),
      SmsPattern(
        name: 'Payment Successful',
        direction: TransactionDirection.outgoing,
        regexPattern: r"Payment to '(.*?)' is Successful\.\s+Amount:\s*Tk\s*([\d,]+(?:\.\d{2})?)\s+TxnID:\s*(\w+)\s+Balance:\s*Tk\s*([\d,]+(?:\.\d{2})?)\s+(\d{2}/\d{2}/\d{4}\s\d{2}:\d{2})",
        fieldMappings: {
          'recipient': '1',
          'amount': '2',
          'transactionId': '3',
          'balance': '4',
          'timestamp': '5',
        },
      ),
      SmsPattern(
        name: 'Send Money Successful',
        direction: TransactionDirection.outgoing,
        regexPattern: r'Send Money Successful\.\s+Amount:\s*Tk\s*([\d,]+(?:\.\d{2})?)\s+Receiver:\s*([\d\*]+)\s+Ref:\s*(.*?)\s+TxnID:\s*(\w+)\s+Fee:\s*Tk\s*[\d,]+(?:\.\d{2})?\s+Balance:\s*Tk\s*([\d,]+(?:\.\d{2})?)\s+(\d{2}/\d{2}/\d{4}\s\d{2}:\d{2})',
        fieldMappings: {
          'amount': '1',
          'recipient': '2',
          'reference': '3',
          'transactionId': '4',
          'balance': '5',
          'timestamp': '6',
        },
      ),
      SmsPattern(
        name: 'Bill Payment Successful',
        direction: TransactionDirection.outgoing,
        regexPattern: r'Bill Payment to (.*?) is successful\.\s+Amount:\s*Tk\s*([\d,]+(?:\.\d{2})?)\s+ID:\s*(.*?)\s+Fee:\s*[\d,]+(?:\.\d{2})?\s+TxnId:\s*(\w+)\s+Date:\s*(\d{2}/\d{2}/\d{4}\s\d{2}:\d{2})',
        fieldMappings: {
          'recipient': '1',
          'amount': '2',
          'reference': '3',
          'transactionId': '4',
          'timestamp': '5',
        },
      ),
      SmsPattern(
        name: 'Money Received',
        direction: TransactionDirection.incoming,
        regexPattern: r'Money Received\.\s+Amount:\s*Tk\s*([\d,]+(?:\.\d{2})?)\s+Sender:\s*([\d\*]+)\s+Ref:\s*(.*?)\s+TxnID:\s*(\w+)\s+Balance:\s*Tk\s*([\d,]+(?:\.\d{2})?)\s+(\d{2}/\d{2}/\d{4}\s\d{2}:\d{2})',
        fieldMappings: {
          'amount': '1',
          'sender': '2',
          'reference': '3',
          'transactionId': '4',
          'balance': '5',
          'timestamp': '6',
        },
      ),
      SmsPattern(
        name: 'bKash Received (Sentence Format)',
        direction: TransactionDirection.incoming,
        regexPattern: r'You have received Tk\s*([\d,]+(?:\.\d{2})?)\s+from\s+(\d{11})\.\s+Fee\s+Tk\s*[\d,]+(?:\.\d{2})?\.\s+Balance\s+Tk\s*([\d,]+(?:\.\d{2})?)\.\s+TrxID\s+(\w+)\s+at\s+(\d{2}/\d{2}/\d{4}\s\d{2}:\d{2})',
        fieldMappings: {
          'amount': '1',
          'sender': '2',
          'balance': '3',
          'transactionId': '4',
          'timestamp': '5',
        },
      ),
      SmsPattern(
        name: 'bKash Received (Sentence Format)',
        direction: TransactionDirection.incoming,
        regexPattern: r'You have received Tk\s*([\d,]+(?:\.\d{2})?)\s+from\s+(\d{11})\.\s+Fee\s+Tk\s*[\d,]+(?:\.\d{2})?\.\s+Balance\s+Tk\s*([\d,]+(?:\.\d{2})?)\.\s+TrxID\s+(\w+)\s+at\s+(\d{2}/\d{2}/\d{4}\s\d{2}:\d{2})',
        fieldMappings: {
          'amount': '1',
          'sender': '2',
          'balance': '3',
          'transactionId': '4',
          'timestamp': '5',
        },
      ),
      SmsPattern(
        name: 'Bill Paid Successful',
        direction: TransactionDirection.outgoing,
        regexPattern: r'Bill successfully paid\.\s+Biller:\s*(.*?)\s+MMYYYY/Contact:\s*(.*?)\s+A/C:\s*(\w+)\s+Amount:\s*Tk\s*([\d,]+(?:\.\d{2})?)\s+Fee:\s*Tk\s*[\d,]+(?:\.\d{2})?\s+TrxID:\s*(\w+)\s+at\s+(\d{2}/\d{2}/\d{4}\s\d{2}:\d{2})',
        fieldMappings: {
          'recipient': '1',
          'reference': '2',
          'sender': '3', // Mapping A/C as sender/source account
          'amount': '4',
          'transactionId': '5',
          'timestamp': '6',
        },
      ),
      SmsPattern(
        name: 'Cash In Successful (Sentence Format)',
        direction: TransactionDirection.incoming,
        regexPattern: r'Cash In Tk\s*([\d,]+(?:\.\d{2})?)\s+from\s+(\d{11})\s+successful\.\s+Fee\s+Tk\s*[\d,]+(?:\.\d{2})?\.\s+Balance\s+Tk\s*([\d,]+(?:\.\d{2})?)\.\s+TrxID\s+(\w+)\s+at\s+(\d{2}/\d{2}/\d{4}\s\d{2}:\d{2})',
        fieldMappings: {
          'amount': '1',
          'sender': '2',
          'balance': '3',
          'transactionId': '4',
          'timestamp': '5',
        },
      ),
      
    ];
  }
}
