import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import 'package:intl/intl.dart';

class ReportProvider with ChangeNotifier {
  double todaySales = 0.0;
  double todayProfit = 0.0;
  int lowStockItems = 0;
  
  // New Data for UI
  List<Map<String, dynamic>> recentTransactions = [];
  List<double> weeklySales = List.filled(7, 0.0); // Mon-Sun

  Future<void> loadDashboardStats() async {
    final db = await DatabaseHelper.instance.database;
    
    // 1. Today's Stats
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final salesResult = await db.rawQuery('''
      SELECT SUM(total_price) as total, SUM(profit) as profit 
      FROM sales 
      WHERE date_time LIKE ?
    ''', ['$todayStr%']);

    todaySales = (salesResult.first['total'] as double?) ?? 0.0;
    todayProfit = (salesResult.first['profit'] as double?) ?? 0.0;

    // 2. Low Stock Count
    final stockResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM products WHERE stock_qty < 5'
    );
    lowStockItems = (stockResult.first['count'] as int?) ?? 0;

    // 3. Recent Transactions (Join with Products to get Name)
    // Assuming 'sales' table has 'product_id' and 'products' table has 'id' (or we map via barcode)
    // Adjust logic if your schema uses barcodes.
    final txResult = await db.rawQuery('''
      SELECT s.id, p.name, s.quantity, s.total_price, s.date_time 
      FROM sales s
      JOIN products p ON s.product_id = p.id 
      ORDER BY s.date_time DESC 
      LIMIT 10
    ''');

    recentTransactions = txResult.map((row) {
      return {
        'id': row['id'], // or generate a short ID
        'name': row['name'],
        'quantity': row['quantity'],
        'amount': row['total_price'],
        'time': DateFormat('h:mm a').format(DateTime.parse(row['date_time'] as String)),
      };
    }).toList();

    // 4. Weekly Chart Data (Last 7 Days)
    // This query sums sales per day. 
    // SQLite strftime('%w') returns 0=Sunday, 1=Monday...
    final chartResult = await db.rawQuery('''
      SELECT strftime('%w', date_time) as day_index, SUM(total_price) as total
      FROM sales
      WHERE date_time >= date('now', '-6 days')
      GROUP BY day_index
    ''');

    // Reset list
    weeklySales = List.filled(7, 0.0);
    
    // Fill list based on day index (adjusting so Mon=0, Sun=6 if needed)
    for (var row in chartResult) {
      int dbDay = int.parse(row['day_index'] as String); // 0=Sun, 1=Mon
      double total = (row['total'] as double?) ?? 0.0;
      
      // Map SQLite Sunday(0) to Index 6, Mon(1) to Index 0...
      int listIndex = (dbDay == 0) ? 6 : dbDay - 1;
      if (listIndex >= 0 && listIndex < 7) {
        weeklySales[listIndex] = total;
      }
    }

    notifyListeners();
  }
}