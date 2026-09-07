import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../db/database_helper.dart';
import '../models/daily_closing.dart';

class ReportProvider with ChangeNotifier {
  double todaySales = 0.0;
  double todayProfit = 0.0;
  double todayExpenses = 0.0;
  double get todayNetProfit => todayProfit - todayExpenses;
  int todayTransactionsCount = 0;
  double get averageBasketSize => todayTransactionsCount > 0 ? (todaySales / todayTransactionsCount) : 0.0;

  int lowStockItems = 0;
  
  // Smart Insights Data
  String? topSellingProductName;
  double topSellingProductQty = 0.0;
  String? criticalStockName;
  double criticalStockQty = 0.0;
  double totalOutstandingDebt = 0.0;
  int debtorCount = 0;
  double salesGrowthPercentage = 0.0; // Comparison vs yesterday

  // List Data for UI
  List<Map<String, dynamic>> recentTransactions = [];
  List<double> weeklySales = List.filled(7, 0.0); // Mon-Sun

  Future<void> loadDashboardStats() async {
    final db = await DatabaseHelper.instance.database;
    
    // 1. Today's Date Strings
    final now = DateTime.now();
    final todayStr = now.toIso8601String().substring(0, 10);
    final yesterdayStr = now.subtract(const Duration(days: 1)).toIso8601String().substring(0, 10);

    // 2. Today's Sales & Profit
    final salesResult = await db.rawQuery('''
      SELECT SUM(total_price) as total, SUM(profit) as profit, COUNT(*) as count 
      FROM sales 
      WHERE date_time LIKE ?
    ''', ['$todayStr%']);

    todaySales = (salesResult.first['total'] as num?)?.toDouble() ?? 0.0;
    todayProfit = (salesResult.first['profit'] as num?)?.toDouble() ?? 0.0;
    todayTransactionsCount = (salesResult.first['count'] as int?) ?? 0;

    // 3. Today's Expenses
    try {
      final expenseResult = await db.rawQuery('''
        SELECT SUM(amount) as total 
        FROM expenses 
        WHERE date_time LIKE ?
      ''', ['$todayStr%']);
      todayExpenses = (expenseResult.first['total'] as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      todayExpenses = 0.0;
    }

    // 4. Yesterday's Sales for Growth Comparison
    final yesterdayResult = await db.rawQuery('''
      SELECT SUM(total_price) as total 
      FROM sales 
      WHERE date_time LIKE ?
    ''', ['$yesterdayStr%']);
    final double yesterdaySales = (yesterdayResult.first['total'] as num?)?.toDouble() ?? 0.0;
    if (yesterdaySales > 0) {
      salesGrowthPercentage = ((todaySales - yesterdaySales) / yesterdaySales) * 100;
    } else if (todaySales > 0) {
      salesGrowthPercentage = 100.0;
    } else {
      salesGrowthPercentage = 0.0;
    }

    // 5. Top Selling Product Today
    final topProductResult = await db.rawQuery('''
      SELECT p.name, SUM(s.quantity) as total_qty 
      FROM sales s
      JOIN products p ON s.product_id = p.id
      WHERE s.date_time LIKE ?
      GROUP BY s.product_id
      ORDER BY total_qty DESC
      LIMIT 1
    ''', ['$todayStr%']);

    if (topProductResult.isNotEmpty) {
      topSellingProductName = topProductResult.first['name'] as String?;
      topSellingProductQty = (topProductResult.first['total_qty'] as num?)?.toDouble() ?? 0.0;
    } else {
      topSellingProductName = null;
      topSellingProductQty = 0.0;
    }

    // 6. Critical Low Stock & Low Stock Count
    final stockResult = await db.rawQuery(
      'SELECT COUNT(*) as count FROM products WHERE stock_qty < 5'
    );
    lowStockItems = (stockResult.first['count'] as int?) ?? 0;

    final criticalStockResult = await db.rawQuery('''
      SELECT name, stock_qty 
      FROM products 
      WHERE stock_qty <= 3 AND stock_qty > 0 
      ORDER BY stock_qty ASC 
      LIMIT 1
    ''');
    if (criticalStockResult.isNotEmpty) {
      criticalStockName = criticalStockResult.first['name'] as String?;
      criticalStockQty = (criticalStockResult.first['stock_qty'] as num?)?.toDouble() ?? 0.0;
    } else {
      criticalStockName = null;
      criticalStockQty = 0.0;
    }

    // 7. Total Outstanding Customer Debt
    try {
      final debtResult = await db.rawQuery('''
        SELECT SUM(current_debt) as total_debt, COUNT(*) as count 
        FROM customers 
        WHERE current_debt > 0
      ''');
      totalOutstandingDebt = (debtResult.first['total_debt'] as num?)?.toDouble() ?? 0.0;
      debtorCount = (debtResult.first['count'] as int?) ?? 0;
    } catch (e) {
      totalOutstandingDebt = 0.0;
      debtorCount = 0;
    }

    // 8. Recent Transactions (Join with Products)
    final txResult = await db.rawQuery('''
      SELECT s.id, s.product_id, p.name, s.quantity, s.total_price, s.date_time 
      FROM sales s
      JOIN products p ON s.product_id = p.id 
      ORDER BY s.date_time DESC 
      LIMIT 10
    ''');

    recentTransactions = txResult.map((row) {
      return {
        'id': row['id'],
        'product_id': row['product_id'],
        'name': row['name'],
        'quantity': (row['quantity'] as num?)?.toDouble() ?? 0.0,
        'amount': (row['total_price'] as num?)?.toDouble() ?? 0.0,
        'time': DateFormat('h:mm a').format(DateTime.parse(row['date_time'] as String)),
      };
    }).toList();

    // 9. Weekly Chart Data (Last 7 Days)
    final chartResult = await db.rawQuery('''
      SELECT strftime('%w', date_time) as day_index, SUM(total_price) as total
      FROM sales
      WHERE date_time >= date('now', '-6 days')
      GROUP BY day_index
    ''');

    weeklySales = List.filled(7, 0.0);
    for (var row in chartResult) {
      int dbDay = int.parse(row['day_index'] as String); // 0=Sun, 1=Mon
      double total = (row['total'] as num?)?.toDouble() ?? 0.0;
      
      int listIndex = (dbDay == 0) ? 6 : dbDay - 1;
      if (listIndex >= 0 && listIndex < 7) {
        weeklySales[listIndex] = total;
      }
    }

    // 10. Compute 5-Pillar Business Health Score
    _computeBusinessHealth(db);

    notifyListeners();
  }

  BusinessHealth businessHealth = BusinessHealth.initial();

  Future<void> _computeBusinessHealth(dynamic db) async {
    // 1. Sales Score (0 - 100)
    int sScore = 50;
    if (todaySales > 0) sScore += 20;
    if (todayTransactionsCount >= 5) sScore += 15;
    if (salesGrowthPercentage >= 0) sScore += 15;
    sScore = sScore.clamp(20, 100);

    // 2. Profit Margin Score (0 - 100)
    int pScore = 50;
    if (todaySales > 0) {
      double margin = (todayProfit / todaySales) * 100;
      if (margin >= 30) {
        pScore = 95;
      } else if (margin >= 20) {
        pScore = 80;
      } else if (margin >= 10) {
        pScore = 65;
      } else {
        pScore = 40;
      }
    } else {
      pScore = 60;
    }

    // 3. Inventory Health Score (0 - 100)
    int iScore = 90;
    try {
      final totalStockRes = await db.rawQuery('SELECT COUNT(*) as count FROM products');
      final totalStock = (totalStockRes.first['count'] as int?) ?? 0;
      final outStockRes = await db.rawQuery('SELECT COUNT(*) as count FROM products WHERE stock_qty == 0');
      final outStock = (outStockRes.first['count'] as int?) ?? 0;

      if (totalStock > 0) {
        double penalty = (outStock * 20.0) + (lowStockItems * 8.0);
        iScore = (100 - penalty).round().clamp(20, 100);
      }
    } catch (_) {
      iScore = 75;
    }

    // 4. Debt Risk Score (0 - 100)
    int dScore = 100;
    if (totalOutstandingDebt > 0) {
      if (todaySales > 0 && totalOutstandingDebt > (todaySales * 3)) {
        dScore = 50;
      } else if (totalOutstandingDebt > 5000) {
        dScore = 65;
      } else {
        dScore = 80;
      }
    }

    // 5. Expense Control Score (0 - 100)
    int eScore = 90;
    if (todayProfit > 0) {
      double expRatio = todayExpenses / todayProfit;
      if (expRatio <= 0.2) {
        eScore = 95;
      } else if (expRatio <= 0.5) {
        eScore = 80;
      } else if (expRatio <= 0.8) {
        eScore = 60;
      } else {
        eScore = 40;
      }
    } else if (todayExpenses > 0) {
      eScore = 45;
    }

    // Weighted Overall Score
    int overall = ((sScore * 0.25) + (pScore * 0.25) + (iScore * 0.20) + (dScore * 0.15) + (eScore * 0.15)).round().clamp(0, 100);

    // Determine Lowest Pillar for Actionable Advice
    String advTitle = "Strong Business Health";
    String advMsg = "Operations and cash flow are balanced. Continue monitoring daily inventory.";

    final scores = {
      'Inventory': iScore,
      'Debt': dScore,
      'Expenses': eScore,
      'Profit': pScore,
      'Sales': sScore,
    };

    final lowest = scores.entries.reduce((a, b) => a.value < b.value ? a : b);

    if (lowest.key == 'Inventory' && lowest.value < 75) {
      advTitle = "Inventory Opportunity";
      advMsg = "Products are running out or out of stock. Restock top items to prevent lost sales.";
    } else if (lowest.key == 'Debt' && lowest.value < 75) {
      advTitle = "Debt Collection Action";
      advMsg = "Customer credit balance is elevated. Use WhatsApp account statements to collect payments.";
    } else if (lowest.key == 'Expenses' && lowest.value < 75) {
      advTitle = "Expense Alert";
      advMsg = "Operating costs are high relative to gross profit today. Review non-essential expenses.";
    } else if (lowest.key == 'Profit' && lowest.value < 75) {
      advTitle = "Margin Expansion";
      advMsg = "Profit margins are under pressure. Consider increasing sell prices on fast-moving goods.";
    } else if (lowest.key == 'Sales' && lowest.value < 75) {
      advTitle = "Sales Growth";
      advMsg = "Sales volume is lower than target. Promote featured products or offer bundle deals.";
    }

    businessHealth = BusinessHealth(
      overallScore: overall,
      salesScore: sScore,
      profitScore: pScore,
      inventoryScore: iScore,
      debtScore: dScore,
      expenseScore: eScore,
      adviceTitle: advTitle,
      adviceMessage: advMsg,
    );
  }

  // 11. DAILY CLOSING / Z-REPORT GENERATION
  Future<DailyClosing> getClosingBreakdown({double startingFloat = 0.0, double actualCash = 0.0, String? notes}) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();
    final todayStr = now.toIso8601String().substring(0, 10);

    // Sales by Payment Method
    double cashSales = 0.0;
    double mpesaSales = 0.0;
    double creditSales = 0.0;
    double grossSales = 0.0;
    double totalProfit = 0.0;

    final salesRows = await db.rawQuery('''
      SELECT payment_method, SUM(total_price) as total, SUM(profit) as total_profit
      FROM sales
      WHERE date_time LIKE ?
      GROUP BY payment_method
    ''', ['$todayStr%']);

    for (var row in salesRows) {
      final method = (row['payment_method'] as String?)?.toLowerCase() ?? 'cash';
      final total = (row['total'] as num?)?.toDouble() ?? 0.0;
      final profit = (row['total_profit'] as num?)?.toDouble() ?? 0.0;

      grossSales += total;
      totalProfit += profit;

      if (method.contains('mpesa') || method.contains('m-pesa')) {
        mpesaSales += total;
      } else if (method.contains('credit') || method.contains('deni')) {
        creditSales += total;
      } else {
        cashSales += total;
      }
    }

    // Today's Expenses
    double expenses = 0.0;
    try {
      final expRows = await db.rawQuery('''
        SELECT SUM(amount) as total FROM expenses WHERE date_time LIKE ?
      ''', ['$todayStr%']);
      expenses = (expRows.first['total'] as num?)?.toDouble() ?? 0.0;
    } catch (_) {
      expenses = 0.0;
    }

    final netProfit = totalProfit - expenses;
    final expectedCash = startingFloat + cashSales - expenses;
    final cashDifference = actualCash - expectedCash;

    return DailyClosing(
      date: todayStr,
      startingFloat: startingFloat,
      grossSales: grossSales,
      cashSales: cashSales,
      mpesaSales: mpesaSales,
      creditSales: creditSales,
      totalProfit: totalProfit,
      totalExpenses: expenses,
      netProfit: netProfit,
      expectedCash: expectedCash,
      actualCash: actualCash,
      cashDifference: cashDifference,
      closedAt: now,
      notes: notes,
    );
  }

  Future<void> saveDailyClosing(DailyClosing closing) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('daily_closings', closing.toMap());
    notifyListeners();
  }

  Future<List<DailyClosing>> getPastClosings() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query('daily_closings', orderBy: 'closed_at DESC', limit: 30);
    return result.map((json) => DailyClosing.fromMap(json)).toList();
  }

  Future<void> sendWhatsAppZReport(DailyClosing closing, String shopName, String recipientPhone) async {
    String phone = recipientPhone.trim();
    if (phone.startsWith('0')) {
      phone = "254${phone.substring(1)}";
    } else if (phone.startsWith('+254')) {
      phone = phone.substring(1);
    }

    final timeStr = DateFormat('dd MMM yyyy, h:mm a').format(closing.closedAt);
    final diff = closing.cashDifference;
    final diffStr = diff == 0 ? "Balanced (KES 0)" : (diff > 0 ? "Overage (+KES ${diff.abs().toStringAsFixed(0)})" : "Shortage (-KES ${diff.abs().toStringAsFixed(0)})");

    final buffer = StringBuffer();
    buffer.writeln("==============================");
    buffer.writeln("DAILY CLOSING SUMMARY (Z-REPORT)");
    buffer.writeln("==============================");
    buffer.writeln("Store: $shopName");
    buffer.writeln("Date: ${closing.date}");
    buffer.writeln("Closed At: $timeStr");
    buffer.writeln("------------------------------");
    buffer.writeln("REVENUE BREAKDOWN:");
    buffer.writeln("• Cash Sales: KES ${closing.cashSales.toStringAsFixed(0)}");
    buffer.writeln("• M-Pesa Sales: KES ${closing.mpesaSales.toStringAsFixed(0)}");
    buffer.writeln("• Credit (Deni): KES ${closing.creditSales.toStringAsFixed(0)}");
    buffer.writeln("• GROSS SALES: KES ${closing.grossSales.toStringAsFixed(0)}");
    buffer.writeln("------------------------------");
    buffer.writeln("PROFIT & EXPENSES:");
    buffer.writeln("• Gross Profit: KES ${closing.totalProfit.toStringAsFixed(0)}");
    buffer.writeln("• Total Expenses: -KES ${closing.totalExpenses.toStringAsFixed(0)}");
    buffer.writeln("• NET PROFIT: KES ${closing.netProfit.toStringAsFixed(0)}");
    buffer.writeln("------------------------------");
    buffer.writeln("CASH RECONCILIATION:");
    buffer.writeln("• Starting Float: KES ${closing.startingFloat.toStringAsFixed(0)}");
    buffer.writeln("• Expected Cash: KES ${closing.expectedCash.toStringAsFixed(0)}");
    buffer.writeln("• Counted Cash: KES ${closing.actualCash.toStringAsFixed(0)}");
    buffer.writeln("• Discrepancy: $diffStr");
    if (closing.notes != null && closing.notes!.isNotEmpty) {
      buffer.writeln("• Notes: ${closing.notes}");
    }
    buffer.writeln("==============================");
    buffer.writeln("Generated via M-Bizna");

    final url = Uri.parse("https://wa.me/$phone?text=${Uri.encodeComponent(buffer.toString())}");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}

class BusinessHealth {
  final int overallScore;
  final int salesScore;
  final int profitScore;
  final int inventoryScore;
  final int debtScore;
  final int expenseScore;
  final String adviceTitle;
  final String adviceMessage;

  BusinessHealth({
    required this.overallScore,
    required this.salesScore,
    required this.profitScore,
    required this.inventoryScore,
    required this.debtScore,
    required this.expenseScore,
    required this.adviceTitle,
    required this.adviceMessage,
  });

  factory BusinessHealth.initial() {
    return BusinessHealth(
      overallScore: 80,
      salesScore: 75,
      profitScore: 80,
      inventoryScore: 85,
      debtScore: 90,
      expenseScore: 85,
      adviceTitle: "Business Ready",
      adviceMessage: "Track daily sales and expenses to keep your health score updated.",
    );
  }
}