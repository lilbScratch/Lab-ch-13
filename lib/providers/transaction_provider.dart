import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../models/my_transaction.dart';

class TransactionProvider with ChangeNotifier {
  static const _databaseName = 'expenses.db';
  static const _tableName = 'transactions';

  Future<Database>? _databaseFuture;
  List<MyTransaction> _transactions = [];
  bool _isLoading = true;
  Object? _error;
  double _incomeTotal = 0;
  double _expenseTotal = 0;

  TransactionProvider() {
    unawaited(fetchAndSetTransactions());
  }

  List<MyTransaction> get transactions => List.unmodifiable(_transactions);
  bool get isLoading => _isLoading;
  Object? get error => _error;
  double get incomeTotal => _incomeTotal;
  double get expenseTotal => _expenseTotal;
  double get balance => _incomeTotal - _expenseTotal;

  Future<Database> _openDatabase() async {
    final databasePath = kIsWeb
        ? _databaseName
        : path.join(await getDatabasesPath(), _databaseName);
    return openDatabase(
      databasePath,
      version: 2,
      onCreate: (db, version) => db.execute('''
        CREATE TABLE $_tableName(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          amount REAL NOT NULL,
          date TEXT NOT NULL,
          type TEXT NOT NULL CHECK(type IN ('income', 'expense')),
          note TEXT
        )
      '''),
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE $_tableName ADD COLUMN note TEXT');
        }
      },
    );
  }

  Future<Database> get _database => _databaseFuture ??= _openDatabase();

  Future<void> fetchAndSetTransactions() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final rows = await (await _database).query(
        _tableName,
        orderBy: 'date DESC, id DESC',
      );
      _transactions = rows.map(MyTransaction.fromMap).toList();
      final totals = (await (await _database).rawQuery('''
        SELECT
          COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END), 0) AS income,
          COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) AS expense
        FROM $_tableName
      '''))
          .single;
      _incomeTotal = (totals['income'] as num).toDouble();
      _expenseTotal = (totals['expense'] as num).toDouble();
    } catch (error) {
      _error = error;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addTransaction(
    MyTransaction transaction, {
    bool refresh = true,
  }) async {
    await (await _database).insert(_tableName, transaction.toMap());
    if (refresh) await fetchAndSetTransactions();
  }

  Future<void> updateTransaction(MyTransaction transaction) async {
    final id = transaction.id;
    if (id == null) throw ArgumentError('Transaction id is required to update.');
    await (await _database).update(
      _tableName,
      transaction.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [id],
    );
    await fetchAndSetTransactions();
  }

  Future<void> deleteTransaction(int id) async {
    await (await _database).delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
    await fetchAndSetTransactions();
  }

  Future<Duration> importSamplesOneByOne() async {
    await _database;
    final date = DateTime.now();
    final stopwatch = Stopwatch()..start();
    for (var i = 1; i <= 100; i++) {
      await addTransaction(
        MyTransaction(
          title: 'ตัวอย่างทีละรายการ ${i.toString().padLeft(3, '0')}',
          amount: 25 + (i % 20).toDouble(),
          date: date.subtract(Duration(minutes: i)),
          type: i.isEven ? TransactionType.expense : TransactionType.income,
          note: 'ข้อมูลสำหรับเปรียบเทียบการนำเข้า',
        ),
        refresh: false,
      );
    }
    stopwatch.stop();
    await fetchAndSetTransactions();
    return stopwatch.elapsed;
  }

  Future<Duration> importSamplesBatch() async {
    final db = await _database;
    final date = DateTime.now();
    final stopwatch = Stopwatch()..start();
    await db.transaction((transaction) async {
      final batch = transaction.batch();
      for (var i = 1; i <= 100; i++) {
        batch.insert(
          _tableName,
          MyTransaction(
            title: 'ตัวอย่าง Batch ${i.toString().padLeft(3, '0')}',
            amount: 25 + (i % 20).toDouble(),
            date: date.subtract(Duration(minutes: i)),
            type: i.isEven ? TransactionType.expense : TransactionType.income,
            note: 'ข้อมูลสำหรับเปรียบเทียบการนำเข้า',
          ).toMap(),
        );
      }
      await batch.commit(noResult: true);
    });
    stopwatch.stop();
    await fetchAndSetTransactions();
    return stopwatch.elapsed;
  }

  @override
  void dispose() {
    final database = _databaseFuture;
    if (database != null) {
      unawaited(database.then((db) => db.close()));
    }
    super.dispose();
  }
}
