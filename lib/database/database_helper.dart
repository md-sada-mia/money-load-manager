import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:path/path.dart';
import '../models/models.dart';
import '../services/default_patterns.dart';

/// Database helper for managing local SQLite database
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('money_load_manager.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3, // Upgraded to remove daily_summaries table
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Transactions table
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        direction TEXT NOT NULL DEFAULT 'incoming',
        amount REAL NOT NULL,
        sender TEXT,
        recipient TEXT,
        timestamp INTEGER NOT NULL,
        raw_sms TEXT NOT NULL,
        pattern_id INTEGER,
        notes TEXT
      )
    ''');

    // SMS patterns table
    await db.execute('''
      CREATE TABLE patterns (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        regex_pattern TEXT NOT NULL,
        transaction_type TEXT NOT NULL,
        direction TEXT NOT NULL DEFAULT 'incoming',
        field_mappings TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL
      )
    ''');

    // Daily summaries table removed - summaries are now calculated on-the-fly from transactions

    // Create indexes for better query performance
    await db.execute('CREATE INDEX idx_transactions_timestamp ON transactions(timestamp)');
    await db.execute('CREATE INDEX idx_transactions_type ON transactions(type)');
    await db.execute('CREATE INDEX idx_transactions_direction ON transactions(direction)');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add direction column to transactions table
      await db.execute('''
        ALTER TABLE transactions ADD COLUMN direction TEXT NOT NULL DEFAULT 'incoming'
      ''');

      // Add direction column to patterns table
      await db.execute('''
        ALTER TABLE patterns ADD COLUMN direction TEXT NOT NULL DEFAULT 'incoming'
      ''');

      // Add incoming/outgoing columns to daily_summaries table (will be dropped in v3)
      await db.execute('''
        ALTER TABLE daily_summaries ADD COLUMN incoming_count INTEGER NOT NULL DEFAULT 0
      ''');
      await db.execute('''
        ALTER TABLE daily_summaries ADD COLUMN incoming_amount REAL NOT NULL DEFAULT 0
      ''');
      await db.execute('''
        ALTER TABLE daily_summaries ADD COLUMN outgoing_count INTEGER NOT NULL DEFAULT 0
      ''');
      await db.execute('''
        ALTER TABLE daily_summaries ADD COLUMN outgoing_amount REAL NOT NULL DEFAULT 0
      ''');

      // Create index for direction column
      await db.execute('CREATE INDEX idx_transactions_direction ON transactions(direction)');
    }
    
    if (oldVersion < 3) {
      // Drop daily_summaries table - we now calculate summaries on-the-fly from transactions
      await db.execute('DROP TABLE IF EXISTS daily_summaries');
    }
  }

  // Transaction operations
  Future<int> createTransaction(Transaction transaction) async {
    final db = await database;
    return await db.insert('transactions', transaction.toMap());
  }

  Future<List<Transaction>> getAllTransactions() async {
    final db = await database;
    final result = await db.query('transactions', orderBy: 'timestamp DESC');
    return List<Transaction>.from(result.map((map) => Transaction.fromMap(map)));
  }

  Future<List<Transaction>> getTransactionsByDateRange(DateTime start, DateTime end) async {
    final db = await database;
    final result = await db.query(
      'transactions',
      where: 'timestamp >= ? AND timestamp <= ?',
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      orderBy: 'timestamp DESC',
    );
    return List<Transaction>.from(result.map((map) => Transaction.fromMap(map)));
  }

  Future<List<Transaction>> getTransactionsByType(TransactionType type) async {
    final db = await database;
    final result = await db.query(
      'transactions',
      where: 'type = ?',
      whereArgs: [type.name],
      orderBy: 'timestamp DESC',
    );
    return List<Transaction>.from(result.map((map) => Transaction.fromMap(map)));
  }

  Future<int> updateTransaction(Transaction transaction) async {
    final db = await database;
    return await db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<int> deleteTransaction(int id) async {
    final db = await database;
    return await db.delete(
      'transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<bool> transactionExists(String rawSms) async {
    final db = await database;
    final result = await db.query(
      'transactions',
      where: 'raw_sms = ?',
      whereArgs: [rawSms],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  // Pattern operations
  Future<int> createPattern(SmsPattern pattern) async {
    final db = await database;
    return await db.insert('patterns', pattern.toMap());
  }

  Future<List<SmsPattern>> getAllPatterns() async {
    final db = await database;
    final result = await db.query('patterns', orderBy: 'created_at DESC');
    return List<SmsPattern>.from(result.map((map) => SmsPattern.fromMap(map)));
  }

  Future<List<SmsPattern>> getActivePatterns() async {
    final db = await database;
    final result = await db.query(
      'patterns',
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: 'created_at DESC',
    );
    return List<SmsPattern>.from(result.map((map) => SmsPattern.fromMap(map)));
  }

  Future<int> updatePattern(SmsPattern pattern) async {
    final db = await database;
    return await db.update(
      'patterns',
      pattern.toMap(),
      where: 'id = ?',
      whereArgs: [pattern.id],
    );
  }

  Future<int> deletePattern(int id) async {
    final db = await database;
    return await db.delete(
      'patterns',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Reload default patterns - updates existing patterns or adds new ones
  Future<int> reloadDefaultPatterns() async {
    final defaultPatterns = DefaultPatterns.getDefaultPatterns();
    final existingPatterns = await getAllPatterns();
    
    int updateCount = 0;
    
    for (final defaultPattern in defaultPatterns) {
      // Find matching pattern by name
      final existing = existingPatterns.where((p) => p.name == defaultPattern.name).firstOrNull;
      
      if (existing != null) {
        // Update existing pattern with new regex and mappings
        final updated = existing.copyWith(
          regexPattern: defaultPattern.regexPattern,
          fieldMappings: defaultPattern.fieldMappings,
          transactionType: defaultPattern.transactionType,
        );
        await updatePattern(updated);
        updateCount++;
      } else {
        // Add new pattern
        await createPattern(defaultPattern);
        updateCount++;
      }
    }
    
    return updateCount;
  }


  // Daily summary operations
  // Note: Summaries are now calculated on-the-fly from transactions.
  // The saveDailySummary() and getDailySummary() methods have been removed.

  /// Calculate daily summary from transactions in real-time
  /// Returns a Map with aggregated transaction data
  Future<Map<String, dynamic>> calculateDailySummary(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
    
    final transactions = await getTransactionsByDateRange(startOfDay, endOfDay);

    int flexiloadCount = 0, bkashCount = 0, utilityBillCount = 0, otherCount = 0;
    double flexiloadAmount = 0, bkashAmount = 0, utilityBillAmount = 0, otherAmount = 0;
    int incomingCount = 0, outgoingCount = 0;
    double incomingAmount = 0, outgoingAmount = 0;

    for (var txn in transactions) {
      // Track direction
      if (txn.direction == TransactionDirection.incoming) {
        incomingCount++;
        incomingAmount += txn.amount;
      } else {
        outgoingCount++;
        outgoingAmount += txn.amount;
      }

      // Track by type
      switch (txn.type) {
        case TransactionType.flexiload:
          flexiloadCount++;
          flexiloadAmount += txn.amount;
          break;
        case TransactionType.bkash:
          bkashCount++;
          bkashAmount += txn.amount;
          break;
        case TransactionType.utilityBill:
          utilityBillCount++;
          utilityBillAmount += txn.amount;
          break;
        case TransactionType.other:
          otherCount++;
          otherAmount += txn.amount;
          break;
      }
    }

    return {
      'date': startOfDay,
      'totalCount': transactions.length,
      'totalAmount': flexiloadAmount + bkashAmount + utilityBillAmount + otherAmount,
      'incomingCount': incomingCount,
      'incomingAmount': incomingAmount,
      'outgoingCount': outgoingCount,
      'outgoingAmount': outgoingAmount,
      'flexiloadCount': flexiloadCount,
      'flexiloadAmount': flexiloadAmount,
      'bkashCount': bkashCount,
      'bkashAmount': bkashAmount,
      'utilityBillCount': utilityBillCount,
      'utilityBillAmount': utilityBillAmount,
      'otherCount': otherCount,
      'otherAmount': otherAmount,
    };
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }

  Future<void> deleteAllData() async {
    final db = await database;
    await db.delete('transactions');
    await db.delete('patterns');
    // daily_summaries table has been removed
  }
}
