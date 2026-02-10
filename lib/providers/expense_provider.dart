import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../db/database_helper.dart';

class ExpenseProvider with ChangeNotifier {
  List<Expense> _expenses = [];

  List<Expense> get expenses => _expenses;

  Future<void> loadExpenses() async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> maps = await db.query('expenses', orderBy: 'date_time DESC');
    _expenses = maps.map((e) => Expense.fromMap(e)).toList();
    notifyListeners();
  }

  Future<void> addExpense(Expense expense) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('expenses', expense.toMap());
    await loadExpenses();
  }

  Future<void> deleteExpense(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
    await loadExpenses();
  }

  double get totalExpenses {
    return _expenses.fold(0, (sum, item) => sum + item.amount);
  }
}
