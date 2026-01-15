import 'package:flutter/material.dart';

/// Transaction direction (money flow)
enum TransactionDirection {
  incoming,  // Money received
  outgoing,  // Money sent
}

/// Represents a financial transaction parsed from SMS
class Transaction {
  final int? id;
  final String type; // Now a String (Sender Name or inferred type)
  final TransactionDirection direction;
  final double amount;
  final String? sender;
  final String? recipient;
  final DateTime timestamp;
  final String rawSms;
  final int? patternId;
  final String? notes;
  final String? reference;
  final String? txnId;
  final double? balance;
  final DateTime? smsTimestamp;

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
    this.reference,
    this.txnId,
    this.balance,
    this.smsTimestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'direction': direction.name,
      'amount': amount,
      'sender': sender,
      'recipient': recipient,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'raw_sms': rawSms,
      'pattern_id': patternId,
      'notes': notes,
      'reference': reference,
      'txn_id': txnId,
      'balance': balance,
      'sms_timestamp': smsTimestamp?.millisecondsSinceEpoch,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] as int?,
      type: map['type'] as String? ?? 'Unknown',
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
      reference: map['reference'] as String?,
      txnId: map['txn_id'] as String?,
      balance: (map['balance'] as num?)?.toDouble(),
      smsTimestamp: map['sms_timestamp'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['sms_timestamp'] as int)
          : null,
    );
  }

  Transaction copyWith({
    int? id,
    String? type,
    TransactionDirection? direction,
    double? amount,
    String? sender,
    String? recipient,
    DateTime? timestamp,
    String? rawSms,
    int? patternId,
    String? notes,
    String? reference,
    String? txnId,
    double? balance,
    DateTime? smsTimestamp,
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
      reference: reference ?? this.reference,
      txnId: txnId ?? this.txnId,
      balance: balance ?? this.balance,
      smsTimestamp: smsTimestamp ?? this.smsTimestamp,
    );
  }
}

/// Represents an SMS pattern for transaction detection
class SmsPattern {
  final int? id;
  final String name;
  final String regexPattern;
  final String? transactionType; // Now nullable String (Sender Name or inferred type)
  final TransactionDirection direction;
  final Map<String, String> fieldMappings; // e.g., {"amount": "group1", "sender": "group2"}
  final bool isActive;
  final DateTime createdAt;

  SmsPattern({
    this.id,
    required this.name,
    required this.regexPattern,
    this.transactionType, // Optional
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
      'transaction_type': transactionType,
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
      transactionType: map['transaction_type'] as String?,
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
    String? transactionType,
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

