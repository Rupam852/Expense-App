import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:encrypt/encrypt.dart' as enc;
import '../models/expense.dart';
import '../models/budget.dart';
import '../models/payment_detail.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  // AES-256 Symmetric key and IV setup (Pure Dart cryptography)
  static final _encryptionKey = enc.Key.fromUtf8('groww_secure_app_salt_32_bytes_k'); // 32 characters
  static final _encryptionIV = enc.IV.fromUtf8('groww_sec_iv_16b'); // 16 characters
  static final _crypter = enc.Encrypter(enc.AES(_encryptionKey, mode: enc.AESMode.cbc));

  static String encryptVal(String plainText) {
    if (plainText.isEmpty) return plainText;
    try {
      final encrypted = _crypter.encrypt(plainText, iv: _encryptionIV);
      return encrypted.base64;
    } catch (e) {
      print('Encryption error: $e');
      return plainText;
    }
  }

  static String decryptVal(String cipherText) {
    if (cipherText.isEmpty) return cipherText;
    try {
      final decrypted = _crypter.decrypt64(cipherText, iv: _encryptionIV);
      return decrypted;
    } catch (e) {
      // Return plaintext if decryption fails (self-healing for legacy/plaintext rows)
      return cipherText;
    }
  }

  static List<Map<String, dynamic>> decryptExpenseMaps(List<Map<String, dynamic>> result) {
    return result.map((row) {
      final decryptedRow = Map<String, dynamic>.from(row);
      decryptedRow['amount'] = decryptVal(row['amount']?.toString() ?? '');
      decryptedRow['category'] = decryptVal(row['category']?.toString() ?? 'Others');
      decryptedRow['description'] = decryptVal(row['description']?.toString() ?? '');
      return decryptedRow;
    }).toList();
  }

  static List<Map<String, dynamic>> decryptBudgetMaps(List<Map<String, dynamic>> result) {
    return result.map((row) {
      final decryptedRow = Map<String, dynamic>.from(row);
      decryptedRow['category'] = decryptVal(row['category']?.toString() ?? 'Others');
      decryptedRow['amount_limit'] = decryptVal(row['amount_limit']?.toString() ?? '0.0');
      return decryptedRow;
    }).toList();
  }

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
      version: 3,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        await db.execute('ALTER TABLE budgets ADD COLUMN is_deleted INTEGER NOT NULL DEFAULT 0');
      } catch (e) {
        print('Budgets migration error: $e');
      }
    }
    if (oldVersion < 3) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS deleted_records (
            id TEXT PRIMARY KEY,
            table_name TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
      } catch (e) {
        print('Deleted records migration error: $e');
      }
    }
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
        is_deleted INTEGER NOT NULL DEFAULT 0,
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

    // 4. Deleted Records SQLite Table
    await db.execute('''
      CREATE TABLE deleted_records (
        id TEXT PRIMARY KEY,
        table_name TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  // ================= EXPENSES CRUD =================

  Future<int> insertExpense(Expense expense) async {
    final db = await instance.database;
    final map = expense.toMap();
    map['is_synced'] = 0; // Unsynced
    map['amount'] = encryptVal(map['amount'].toString());
    map['category'] = encryptVal(map['category'].toString());
    map['description'] = encryptVal(map['description'].toString());
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
    final decrypted = decryptExpenseMaps(result);
    return decrypted.map((json) => Expense.fromMap(json)).toList();
  }

  Future<Expense?> getExpenseById(String id) async {
    final db = await instance.database;
    final maps = await db.query(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      final decrypted = decryptExpenseMaps(maps);
      return Expense.fromMap(decrypted.first);
    }
    return null;
  }

  Future<int> updateExpense(Expense expense) async {
    final db = await instance.database;
    final map = expense.toMap();
    map['is_synced'] = 0; // Set to unsynced so background sync is triggered
    map['updated_at'] = DateTime.now().toIso8601String();
    map['amount'] = encryptVal(map['amount'].toString());
    map['category'] = encryptVal(map['category'].toString());
    map['description'] = encryptVal(map['description'].toString());

    return await db.update(
      'expenses',
      map,
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  // Hard delete and log inside deleted_records sync queue
  Future<int> deleteExpense(String id) async {
    final db = await instance.database;
    await db.insert(
      'deleted_records',
      {
        'id': id,
        'table_name': 'expenses',
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return await db.delete(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

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
    map['category'] = encryptVal(map['category'].toString());
    map['amount_limit'] = encryptVal(map['amount_limit'].toString());
    return await db.insert(
      'budgets',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Budget>> getBudgets() async {
    final db = await instance.database;
    final result = await db.query(
      'budgets',
      where: 'is_deleted = 0',
      orderBy: 'month_year DESC',
    );
    final decrypted = decryptBudgetMaps(result);
    return decrypted.map((json) => Budget.fromMap(json)).toList();
  }

  Future<Budget?> getBudgetById(String id) async {
    final db = await instance.database;
    final maps = await db.query(
      'budgets',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      final decrypted = decryptBudgetMaps(maps);
      return Budget.fromMap(decrypted.first);
    }
    return null;
  }

  Future<int> updateBudget(Budget budget) async {
    final db = await instance.database;
    final map = budget.toMap();
    map['is_synced'] = 0;
    map['updated_at'] = DateTime.now().toIso8601String();
    map['category'] = encryptVal(map['category'].toString());
    map['amount_limit'] = encryptVal(map['amount_limit'].toString());

    return await db.update(
      'budgets',
      map,
      where: 'id = ?',
      whereArgs: [budget.id],
    );
  }

  // Hard delete and log inside deleted_records sync queue
  Future<int> deleteBudget(String id) async {
    final db = await instance.database;
    await db.insert(
      'deleted_records',
      {
        'id': id,
        'table_name': 'budgets',
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return await db.delete(
      'budgets',
      where: 'id = ?',
      whereArgs: [id],
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

  // ================= DELETIONS QUEUE UTILITIES =================

  Future<List<Map<String, dynamic>>> getUnsyncedDeletions() async {
    final db = await instance.database;
    return await db.query('deleted_records');
  }

  Future<void> clearSyncedDeletions(List<String> ids) async {
    final db = await instance.database;
    if (ids.isEmpty) return;
    await db.delete(
      'deleted_records',
      where: 'id IN (${ids.map((_) => '?').join(', ')})',
      whereArgs: ids,
    );
  }

  Future<void> applyDownloadedDeletions(List<dynamic> deletions) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      for (final del in deletions) {
        final id = del['id'] as String;
        final tableName = del['table_name'] as String;
        if (tableName == 'expenses' || tableName == 'budgets' || tableName == 'payment_details') {
          await txn.delete(tableName, where: 'id = ?', whereArgs: [id]);
        }
      }
    });
  }

  // ================= SYNCHRONIZATION QUEUE QUERY UTILITIES =================

  // Fetch all items not yet synced
  Future<List<Map<String, dynamic>>> getUnsyncedExpenses() async {
    final db = await instance.database;
    final result = await db.query('expenses', where: 'is_synced = 0');
    final decrypted = decryptExpenseMaps(result);
    return decrypted.map((row) {
      final newRow = Map<String, dynamic>.from(row);
      newRow['amount'] = double.tryParse(row['amount']?.toString() ?? '') ?? 0.0;
      newRow['is_recurring'] = row['is_recurring'] == 1 || row['is_recurring'] == true;
      newRow['is_deleted'] = row['is_deleted'] == 1 || row['is_deleted'] == true;
      return newRow;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getUnsyncedBudgets() async {
    final db = await instance.database;
    final result = await db.query('budgets', where: 'is_synced = 0');
    final decrypted = decryptBudgetMaps(result);
    return decrypted.map((row) {
      final newRow = Map<String, dynamic>.from(row);
      newRow['amount_limit'] = double.tryParse(row['amount_limit']?.toString() ?? '') ?? 0.0;
      newRow['is_deleted'] = row['is_deleted'] == 1 || row['is_deleted'] == true;
      return newRow;
    }).toList();
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
          map['amount'] = encryptVal(map['amount'].toString());
          map['category'] = encryptVal(map['category'].toString());
          map['description'] = encryptVal(map['description'].toString());
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
        if (bud.isDeleted) {
          await txn.delete('budgets', where: 'id = ?', whereArgs: [bud.id]);
        } else {
          final map = bud.toMap();
          map['is_synced'] = 1;
          map['category'] = encryptVal(map['category'].toString());
          map['amount_limit'] = encryptVal(map['amount_limit'].toString());
          await txn.insert(
            'budgets',
            map,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
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
    await db.delete('deleted_records');
  }

  Future<void> close() async {
    final db = await _database;
    if (db != null) {
      await db.close();
    }
  }
}
