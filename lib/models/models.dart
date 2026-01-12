/// Transaction types supported by the app
enum TransactionType {
  flexiload,
  bkash,
  utilityBill,
  other,
}

/// Transaction direction (money flow)
enum TransactionDirection {
  incoming,  // Money received
  outgoing,  // Money sent
}

/// Represents a financial transaction parsed from SMS
class Transaction {
  final int? id;
  final TransactionType type;
  final TransactionDirection direction;
  final double amount;
  final String? sender;
  final String? recipient;
  final DateTime timestamp;
  final String rawSms;
  final int? patternId;
  final String? notes;

  Transaction({
    this.id,
    required this.type,
    required this.direction,
    required this.amount,
    this.sender,
    this.recipient,
    required this.timestamp,
    required this.rawSms,
    this.patternId,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'direction': direction.name,
      'amount': amount,
      'sender': sender,
      'recipient': recipient,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'raw_sms': rawSms,
      'pattern_id': patternId,
      'notes': notes,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] as int?,
      type: TransactionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => TransactionType.other,
      ),
      direction: TransactionDirection.values.firstWhere(
        (e) => e.name == map['direction'],
        orElse: () => TransactionDirection.incoming, // Default for old data
      ),
      amount: (map['amount'] as num).toDouble(),
      sender: map['sender'] as String?,
      recipient: map['recipient'] as String?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      rawSms: map['raw_sms'] as String,
      patternId: map['pattern_id'] as int?,
      notes: map['notes'] as String?,
    );
  }

  Transaction copyWith({
    int? id,
    TransactionType? type,
    TransactionDirection? direction,
    double? amount,
    String? sender,
    String? recipient,
    DateTime? timestamp,
    String? rawSms,
    int? patternId,
    String? notes,
  }) {
    return Transaction(
      id: id ?? this.id,
      type: type ?? this.type,
      direction: direction ?? this.direction,
      amount: amount ?? this.amount,
      sender: sender ?? this.sender,
      recipient: recipient ?? this.recipient,
      timestamp: timestamp ?? this.timestamp,
      rawSms: rawSms ?? this.rawSms,
      patternId: patternId ?? this.patternId,
      notes: notes ?? this.notes,
    );
  }
}

/// Represents an SMS pattern for transaction detection
class SmsPattern {
  final int? id;
  final String name;
  final String regexPattern;
  final TransactionType transactionType;
  final TransactionDirection direction;
  final Map<String, String> fieldMappings; // e.g., {"amount": "group1", "sender": "group2"}
  final bool isActive;
  final DateTime createdAt;

  SmsPattern({
    this.id,
    required this.name,
    required this.regexPattern,
    required this.transactionType,
    required this.direction,
    required this.fieldMappings,
    this.isActive = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'regex_pattern': regexPattern,
      'transaction_type': transactionType.name,
      'direction': direction.name,
      'field_mappings': _encodeFieldMappings(fieldMappings),
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory SmsPattern.fromMap(Map<String, dynamic> map) {
    return SmsPattern(
      id: map['id'] as int?,
      name: map['name'] as String,
      regexPattern: map['regex_pattern'] as String,
      transactionType: TransactionType.values.firstWhere(
        (e) => e.name == map['transaction_type'],
        orElse: () => TransactionType.other,
      ),
      direction: TransactionDirection.values.firstWhere(
        (e) => e.name == map['direction'],
        orElse: () => TransactionDirection.incoming, // Default for old data
      ),
      fieldMappings: _decodeFieldMappings(map['field_mappings'] as String),
      isActive: (map['is_active'] as int) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  static String _encodeFieldMappings(Map<String, String> mappings) {
    return mappings.entries.map((e) => '${e.key}:${e.value}').join(',');
  }

  static Map<String, String> _decodeFieldMappings(String encoded) {
    if (encoded.isEmpty) return {};
    return Map.fromEntries(
      encoded.split(',').map((e) {
        final parts = e.split(':');
        return MapEntry(parts[0], parts[1]);
      }),
    );
  }

  SmsPattern copyWith({
    int? id,
    String? name,
    String? regexPattern,
    TransactionType? transactionType,
    TransactionDirection? direction,
    Map<String, String>? fieldMappings,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return SmsPattern(
      id: id ?? this.id,
      name: name ?? this.name,
      regexPattern: regexPattern ?? this.regexPattern,
      transactionType: transactionType ?? this.transactionType,
      direction: direction ?? this.direction,
      fieldMappings: fieldMappings ?? this.fieldMappings,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Daily summary of transactions
class DailySummary {
  final DateTime date;
  final int totalCount;
  final double totalAmount;
  final int incomingCount;
  final double incomingAmount;
  final int outgoingCount;
  final double outgoingAmount;
  final int flexiloadCount;
  final double flexiloadAmount;
  final int bkashCount;
  final double bkashAmount;
  final int utilityBillCount;
  final double utilityBillAmount;
  final int otherCount;
  final double otherAmount;

  DailySummary({
    required this.date,
    required this.totalCount,
    required this.totalAmount,
    required this.incomingCount,
    required this.incomingAmount,
    required this.outgoingCount,
    required this.outgoingAmount,
    required this.flexiloadCount,
    required this.flexiloadAmount,
    required this.bkashCount,
    required this.bkashAmount,
    required this.utilityBillCount,
    required this.utilityBillAmount,
    required this.otherCount,
    required this.otherAmount,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': _dateToString(date),
      'total_count': totalCount,
      'total_amount': totalAmount,
      'incoming_count': incomingCount,
      'incoming_amount': incomingAmount,
      'outgoing_count': outgoingCount,
      'outgoing_amount': outgoingAmount,
      'flexiload_count': flexiloadCount,
      'flexiload_amount': flexiloadAmount,
      'bkash_count': bkashCount,
      'bkash_amount': bkashAmount,
      'utility_bill_count': utilityBillCount,
      'utility_bill_amount': utilityBillAmount,
      'other_count': otherCount,
      'other_amount': otherAmount,
    };
  }

  factory DailySummary.fromMap(Map<String, dynamic> map) {
    return DailySummary(
      date: _stringToDate(map['date'] as String),
      totalCount: map['total_count'] as int,
      totalAmount: (map['total_amount'] as num).toDouble(),
      incomingCount: (map['incoming_count'] as int?) ?? 0,
      incomingAmount: ((map['incoming_amount'] as num?) ?? 0).toDouble(),
      outgoingCount: (map['outgoing_count'] as int?) ?? 0,
      outgoingAmount: ((map['outgoing_amount'] as num?) ?? 0).toDouble(),
      flexiloadCount: map['flexiload_count'] as int,
      flexiloadAmount: (map['flexiload_amount'] as num).toDouble(),
      bkashCount: map['bkash_count'] as int,
      bkashAmount: (map['bkash_amount'] as num).toDouble(),
      utilityBillCount: map['utility_bill_count'] as int,
      utilityBillAmount: (map['utility_bill_amount'] as num).toDouble(),
      otherCount: map['other_count'] as int,
      otherAmount: (map['other_amount'] as num).toDouble(),
    );
  }

  static String _dateToString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static DateTime _stringToDate(String dateStr) {
    final parts = dateStr.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }
}
