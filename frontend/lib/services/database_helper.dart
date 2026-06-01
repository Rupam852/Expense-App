import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/expense.dart';
import '../models/budget.dart';
import '../models/payment_detail.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('expense_app.db');
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
    // 1. Expenses SQLite Table
    await db.execute('''
      CREATE TABLE expenses (
        id TEXT PRIMARY KEY,
        amount REAL NOT NULL,
        currency TEXT NOT NULL,
        category TEXT NOT NULL,
        description TEXT NOT NULL,
        transaction_date TEXT NOT NULL,
        receipt_url TEXT,
        is_recurring INTEGER NOT NULL,
        recurrence_period TEXT NOT NULL,
        is_deleted INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // 2. Budgets SQLite Table
    await db.execute('''
      CREATE TABLE budgets (
        id TEXT PRIMARY KEY,
        category TEXT NOT NULL,
        amount_limit REAL NOT NULL,
        month_year TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // 3. Payment Details SQLite Table
    await db.execute('''
      CREATE TABLE payment_details (
        id TEXT PRIMARY KEY,
        upi_id TEXT NOT NULL,
        qr_code_url TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  // ================= EXPENSES CRUD =================

  Future<int> insertExpense(Expense expense) async {
    final db = await instance.database;
    final map = expense.toMap();
    map['is_synced'] = 0; // Unsynced
    return await db.insert(
      'expenses',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Expense>> getExpenses() async {
    final db = await instance.database;
    final result = await db.query(
      'expenses',
      where: 'is_deleted = 0',
      orderBy: 'transaction_date DESC',
    );
    return result.map((json) => Expense.fromMap(json)).toList();
  }

  Future<Expense?> getExpenseById(String id) async {
    final db = await instance.database;
    final maps = await db.query(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Expense.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateExpense(Expense expense) async {
    final db = await instance.database;
    final map = expense.toMap();
    map['is_synced'] = 0; // Set to unsynced so background sync is triggered
    map['updated_at'] = DateTime.now().toIso8601String();

    return await db.update(
      'expenses',
      map,
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  // Soft delete for syncing safety
  Future<int> deleteExpense(String id) async {
    final db = await instance.database;
    final expense = await getExpenseById(id);
    if (expense != null) {
      final updated = expense.copyWith(
        isDeleted: true,
        updatedAt: DateTime.now(),
      );
      final map = updated.toMap();
      map['is_synced'] = 0; // Mark unsynced soft-deleted record
      return await db.update(
        'expenses',
        map,
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    return 0;
  }

  // Hard delete for post-sync sync logs cleanup or direct wipe
  Future<int> hardDeleteExpense(String id) async {
    final db = await instance.database;
    return await db.delete(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ================= BUDGETS CRUD =================

  Future<int> insertBudget(Budget budget) async {
    final db = await instance.database;
    final map = budget.toMap();
    map['is_synced'] = 0;
    return await db.insert(
      'budgets',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Budget>> getBudgets() async {
    final db = await instance.database;
    final result = await db.query('budgets', orderBy: 'month_year DESC');
    return result.map((json) => Budget.fromMap(json)).toList();
  }

  Future<int> updateBudget(Budget budget) async {
    final db = await instance.database;
    final map = budget.toMap();
    map['is_synced'] = 0;
    map['updated_at'] = DateTime.now().toIso8601String();

    return await db.update(
      'budgets',
      map,
      where: 'id = ?',
      whereArgs: [budget.id],
    );
  }

  // ================= PAYMENT DETAILS CRUD =================

  Future<int> insertPaymentDetail(PaymentDetail paymentDetail) async {
    final db = await instance.database;
    final map = paymentDetail.toMap();
    map['is_synced'] = 0;
    return await db.insert(
      'payment_details',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<PaymentDetail>> getPaymentDetails() async {
    final db = await instance.database;
    final result = await db.query('payment_details');
    return result.map((json) => PaymentDetail.fromMap(json)).toList();
  }

  // ================= SYNCHRONIZATION QUEUE QUERY UTILITIES =================

  // Fetch all items not yet synced
  Future<List<Map<String, dynamic>>> getUnsyncedExpenses() async {
    final db = await instance.database;
    return await db.query('expenses', where: 'is_synced = 0');
  }

  Future<List<Map<String, dynamic>>> getUnsyncedBudgets() async {
    final db = await instance.database;
    return await db.query('budgets', where: 'is_synced = 0');
  }

  Future<List<Map<String, dynamic>>> getUnsyncedPaymentDetails() async {
    final db = await instance.database;
    return await db.query('payment_details', where: 'is_synced = 0');
  }

  // Mark items as synced
  Future<void> markExpensesSynced(List<String> ids) async {
    final db = await instance.database;
    if (ids.isEmpty) return;
    await db.update(
      'expenses',
      {'is_synced': 1},
      where: 'id IN (${ids.map((_) => '?').join(', ')})',
      whereArgs: ids,
    );
  }

  Future<void> markBudgetsSynced(List<String> ids) async {
    final db = await instance.database;
    if (ids.isEmpty) return;
    await db.update(
      'budgets',
      {'is_synced': 1},
      where: 'id IN (${ids.map((_) => '?').join(', ')})',
      whereArgs: ids,
    );
  }

  Future<void> markPaymentDetailsSynced(List<String> ids) async {
    final db = await instance.database;
    if (ids.isEmpty) return;
    await db.update(
      'payment_details',
      {'is_synced': 1},
      where: 'id IN (${ids.map((_) => '?').join(', ')})',
      whereArgs: ids,
    );
  }

  // Bulk upsert backend-delivered items on successful synchronization
  Future<void> syncDownExpenses(List<Expense> expenses) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      for (final exp in expenses) {
        if (exp.isDeleted) {
          await txn.delete('expenses', where: 'id = ?', whereArgs: [exp.id]);
        } else {
          final map = exp.toMap();
          map['is_synced'] = 1; // Mark as clean synced
          await txn.insert(
            'expenses',
            map,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }

  Future<void> syncDownBudgets(List<Budget> budgets) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      for (final bud in budgets) {
        final map = bud.toMap();
        map['is_synced'] = 1;
        await txn.insert(
          'budgets',
          map,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> syncDownPaymentDetails(List<PaymentDetail> payments) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      for (final pay in payments) {
        final map = pay.toMap();
        map['is_synced'] = 1;
        await txn.insert(
          'payment_details',
          map,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  // Clear entire local databases for user sign-out safety
  Future<void> clearAllData() async {
    final db = await instance.database;
    await db.delete('expenses');
    await db.delete('budgets');
    await db.delete('payment_details');
  }

  Future<void> close() async {
    final db = await _database;
    if (db != null) {
      await db.close();
    }
  }
}
