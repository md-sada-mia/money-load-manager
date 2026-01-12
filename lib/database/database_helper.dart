import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/models.dart';

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
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Transactions table
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
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
        field_mappings TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL
      )
    ''');

    // Daily summaries table
    await db.execute('''
      CREATE TABLE daily_summaries (
        date TEXT PRIMARY KEY,
        total_count INTEGER NOT NULL,
        total_amount REAL NOT NULL,
        flexiload_count INTEGER NOT NULL,
        flexiload_amount REAL NOT NULL,
        bkash_count INTEGER NOT NULL,
        bkash_amount REAL NOT NULL,
        utility_bill_count INTEGER NOT NULL,
        utility_bill_amount REAL NOT NULL,
        other_count INTEGER NOT NULL,
        other_amount REAL NOT NULL
      )
    ''');

    // Create indexes for better query performance
    await db.execute('CREATE INDEX idx_transactions_timestamp ON transactions(timestamp)');
    await db.execute('CREATE INDEX idx_transactions_type ON transactions(type)');
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

  // Daily summary operations
  Future<void> saveDailySummary(DailySummary summary) async {
    final db = await database;
    await db.insert(
      'daily_summaries',
      summary.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<DailySummary?> getDailySummary(DateTime date) async {
    final db = await database;
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final result = await db.query(
      'daily_summaries',
      where: 'date = ?',
      whereArgs: [dateStr],
    );
    if (result.isEmpty) return null;
    return DailySummary.fromMap(result.first);
  }

  // Calculate daily summary from transactions
  Future<DailySummary> calculateDailySummary(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
    
    final transactions = await getTransactionsByDateRange(startOfDay, endOfDay);

    int flexiloadCount = 0, bkashCount = 0, utilityBillCount = 0, otherCount = 0;
    double flexiloadAmount = 0, bkashAmount = 0, utilityBillAmount = 0, otherAmount = 0;

    for (var txn in transactions) {
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

    return DailySummary(
      date: startOfDay,
      totalCount: transactions.length,
      totalAmount: flexiloadAmount + bkashAmount + utilityBillAmount + otherAmount,
      flexiloadCount: flexiloadCount,
      flexiloadAmount: flexiloadAmount,
      bkashCount: bkashCount,
      bkashAmount: bkashAmount,
      utilityBillCount: utilityBillCount,
      utilityBillAmount: utilityBillAmount,
      otherCount: otherCount,
      otherAmount: otherAmount,
    );
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }

  Future<void> deleteAllData() async {
    final db = await database;
    await db.delete('transactions');
    await db.delete('patterns');
    await db.delete('daily_summaries');
  }
}
