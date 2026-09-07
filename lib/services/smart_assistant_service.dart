import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/assistant_message.dart';

class SmartAssistantService {
  static Future<AssistantMessage> processQuery(String query) async {
    final cleanQuery = query.toLowerCase().trim();
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final msgId = DateTime.now().millisecondsSinceEpoch.toString();

    // 1. INTENT: Sales / Revenue / Profit Today
    if (_matches(cleanQuery, ['today', 'leo', 'today sales', 'today profit', 'made today', 'revenue today', 'how much today', 'earnings today'])) {
      final salesResult = await db.rawQuery('''
        SELECT 
          COALESCE(SUM(total_price), 0.0) as total_sales,
          COALESCE(SUM(profit), 0.0) as total_profit,
          COUNT(*) as tx_count
        FROM sales 
        WHERE date(date_time) = ?
      ''', [todayStr]);

      final expensesResult = await db.rawQuery('''
        SELECT COALESCE(SUM(amount), 0.0) as total_expenses
        FROM expenses
        WHERE date(date_time) = ?
      ''', [todayStr]);

      final totalSales = (salesResult.first['total_sales'] as num).toDouble();
      final grossProfit = (salesResult.first['total_profit'] as num).toDouble();
      final txCount = (salesResult.first['tx_count'] as num).toInt();
      final totalExpenses = (expensesResult.first['total_expenses'] as num).toDouble();
      final netProfit = grossProfit - totalExpenses;

      return AssistantMessage(
        id: msgId,
        text: "Here is your business performance summary for today (${DateFormat('dd MMM').format(now)}):",
        isUser: false,
        timestamp: DateTime.now(),
        intent: 'REVENUE_TODAY',
        metrics: [
          AssistantMetric(label: "Gross Sales", value: "KES ${totalSales.toStringAsFixed(0)}", icon: Icons.point_of_sale, color: Colors.blue),
          AssistantMetric(label: "Net Profit", value: "KES ${netProfit.toStringAsFixed(0)}", icon: Icons.trending_up, color: Colors.green),
          AssistantMetric(label: "Expenses", value: "KES ${totalExpenses.toStringAsFixed(0)}", icon: Icons.receipt_long_outlined, color: Colors.redAccent),
          AssistantMetric(label: "Transactions", value: "$txCount", icon: Icons.receipt, color: Colors.orange),
        ],
        actions: [
          AssistantAction(label: "View Detailed Reports", icon: Icons.bar_chart_outlined, actionType: AssistantActionType.openReports),
          AssistantAction(label: "Close Business Day", icon: Icons.lock_clock_outlined, actionType: AssistantActionType.openScreen, payload: {'screen': 'close_day'}),
        ],
      );
    }

    // 2. INTENT: Sales / Revenue Yesterday
    if (_matches(cleanQuery, ['yesterday', 'jana', 'yesterday sales', 'yesterday profit'])) {
      final yesterdayStr = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));
      final salesResult = await db.rawQuery('''
        SELECT 
          COALESCE(SUM(total_price), 0.0) as total_sales,
          COALESCE(SUM(profit), 0.0) as total_profit,
          COUNT(*) as tx_count
        FROM sales 
        WHERE date(date_time) = ?
      ''', [yesterdayStr]);

      final expensesResult = await db.rawQuery('''
        SELECT COALESCE(SUM(amount), 0.0) as total_expenses
        FROM expenses
        WHERE date(date_time) = ?
      ''', [yesterdayStr]);

      final totalSales = (salesResult.first['total_sales'] as num).toDouble();
      final grossProfit = (salesResult.first['total_profit'] as num).toDouble();
      final txCount = (salesResult.first['tx_count'] as num).toInt();
      final totalExpenses = (expensesResult.first['total_expenses'] as num).toDouble();
      final netProfit = grossProfit - totalExpenses;

      return AssistantMessage(
        id: msgId,
        text: "Here is what your shop achieved yesterday ($yesterdayStr):",
        isUser: false,
        timestamp: DateTime.now(),
        intent: 'REVENUE_YESTERDAY',
        metrics: [
          AssistantMetric(label: "Gross Sales", value: "KES ${totalSales.toStringAsFixed(0)}", icon: Icons.point_of_sale, color: Colors.blue),
          AssistantMetric(label: "Net Profit", value: "KES ${netProfit.toStringAsFixed(0)}", icon: Icons.trending_up, color: Colors.green),
          AssistantMetric(label: "Expenses", value: "KES ${totalExpenses.toStringAsFixed(0)}", icon: Icons.receipt_long_outlined, color: Colors.redAccent),
          AssistantMetric(label: "Transactions", value: "$txCount", icon: Icons.receipt, color: Colors.orange),
        ],
      );
    }

    // 3. INTENT: Customer Debt / Deni / Who owes money
    if (_matches(cleanQuery, ['debt', 'deni', 'madeni', 'owes', 'owe', 'debtor', 'debtors', 'credit', 'unpaid', 'who owes'])) {
      final debtorsResult = await db.rawQuery('''
        SELECT id, name, phone, debt_balance 
        FROM customers 
        WHERE debt_balance > 0 
        ORDER BY debt_balance DESC
      ''');

      double totalDeni = 0.0;
      final items = <AssistantItem>[];

      for (var row in debtorsResult) {
        final balance = (row['debt_balance'] as num).toDouble();
        totalDeni += balance;

        if (items.length < 5) {
          items.add(AssistantItem(
            title: row['name'] as String,
            subtitle: "Phone: ${row['phone'] ?? 'N/A'}",
            badgeText: "KES ${balance.toStringAsFixed(0)}",
            badgeColor: Colors.redAccent,
            extraData: {
              'id': row['id'],
              'name': row['name'],
              'phone': row['phone'],
              'balance': balance,
            },
          ));
        }
      }

      return AssistantMessage(
        id: msgId,
        text: debtorsResult.isEmpty
            ? "Great news! You currently have zero outstanding customer debt (Deni)."
            : "You have ${debtorsResult.length} customer(s) with active debt totaling KES ${totalDeni.toStringAsFixed(0)}:",
        isUser: false,
        timestamp: DateTime.now(),
        intent: 'DEBT_SUMMARY',
        metrics: [
          AssistantMetric(label: "Total Deni", value: "KES ${totalDeni.toStringAsFixed(0)}", icon: Icons.people_outline, color: Colors.redAccent),
          AssistantMetric(label: "Owing Customers", value: "${debtorsResult.length}", icon: Icons.person_search_outlined, color: Colors.orange),
        ],
        items: items,
        actions: [
          AssistantAction(label: "Open Debt Book", icon: Icons.people_outline, actionType: AssistantActionType.openScreen, payload: {'screen': 'customers'}),
        ],
      );
    }

    // 4. INTENT: Low Stock / Out of Stock / Reorder Needs
    if (_matches(cleanQuery, ['stock', 'reorder', 'low stock', 'out of stock', 'empty', 'depleted', 'bidhaa', 'restock', 'running out'])) {
      final lowStockResult = await db.rawQuery('''
        SELECT id, name, stock_qty, unit, buy_price, sell_price 
        FROM products 
        WHERE stock_qty <= 5 
        ORDER BY stock_qty ASC
      ''');

      final items = <AssistantItem>[];
      int outOfStockCount = 0;

      for (var row in lowStockResult) {
        final qty = (row['stock_qty'] as num).toDouble();
        if (qty <= 0) outOfStockCount++;

        if (items.length < 6) {
          items.add(AssistantItem(
            title: row['name'] as String,
            subtitle: "Cost: KES ${(row['buy_price'] as num).toStringAsFixed(0)} / Sell: KES ${(row['sell_price'] as num).toStringAsFixed(0)}",
            badgeText: qty <= 0 ? "Out of Stock" : "${qty.toInt()} ${row['unit']} left",
            badgeColor: qty <= 0 ? Colors.red : Colors.orange,
            extraData: {'id': row['id'], 'name': row['name']},
          ));
        }
      }

      return AssistantMessage(
        id: msgId,
        text: lowStockResult.isEmpty
            ? "Your inventory is fully stocked! No products are at or below 5 units."
            : "Found ${lowStockResult.length} product(s) needing replenishment ($outOfStockCount completely out of stock):",
        isUser: false,
        timestamp: DateTime.now(),
        intent: 'STOCK_ALERTS',
        metrics: [
          AssistantMetric(label: "Low Stock Items", value: "${lowStockResult.length}", icon: Icons.warning_amber_rounded, color: Colors.orange),
          AssistantMetric(label: "Out of Stock", value: "$outOfStockCount", icon: Icons.remove_shopping_cart_outlined, color: Colors.redAccent),
        ],
        items: items,
        actions: [
          AssistantAction(label: "Order from Suppliers", icon: Icons.local_shipping_outlined, actionType: AssistantActionType.openSuppliers),
          AssistantAction(label: "View Inventory", icon: Icons.inventory_2_outlined, actionType: AssistantActionType.openScreen, payload: {'screen': 'inventory'}),
        ],
      );
    }

    // 5. INTENT: Profit Margins / Highest Margin Products
    if (_matches(cleanQuery, ['margin', 'margins', 'highest profit', 'profitable', 'faida kubwa', 'best margin', 'markup'])) {
      final marginResult = await db.rawQuery('''
        SELECT id, name, buy_price, sell_price, stock_qty, unit,
          (sell_price - buy_price) as unit_profit,
          CASE WHEN sell_price > 0 THEN ((sell_price - buy_price) / sell_price) * 100.0 ELSE 0 END as margin_pct
        FROM products
        WHERE sell_price > 0
        ORDER BY margin_pct DESC
        LIMIT 6
      ''');

      final items = <AssistantItem>[];
      for (var row in marginResult) {
        final margin = (row['margin_pct'] as num).toDouble();
        final unitProfit = (row['unit_profit'] as num).toDouble();

        items.add(AssistantItem(
          title: row['name'] as String,
          subtitle: "Buy: KES ${(row['buy_price'] as num).toStringAsFixed(0)} | Profit: +KES ${unitProfit.toStringAsFixed(0)}/unit",
          badgeText: "${margin.toStringAsFixed(1)}% Margin",
          badgeColor: margin >= 30 ? Colors.green : Colors.blue,
        ));
      }

      return AssistantMessage(
        id: msgId,
        text: "Here are your highest margin products. Promoting these items yields the most net profit per sale:",
        isUser: false,
        timestamp: DateTime.now(),
        intent: 'PROFIT_MARGINS',
        items: items,
        actions: [
          AssistantAction(label: "Open POS to Sell", icon: Icons.point_of_sale, actionType: AssistantActionType.openPos),
        ],
      );
    }

    // 6. INTENT: Best Selling Products / Top Sellers
    if (_matches(cleanQuery, ['top seller', 'top sellers', 'best seller', 'best selling', 'popular', 'fast moving', 'most sold', 'bidhaa bora'])) {
      final topSellerResult = await db.rawQuery('''
        SELECT p.name, p.unit, SUM(s.quantity) as total_qty, SUM(s.total_price) as total_revenue
        FROM sales s
        JOIN products p ON s.product_id = p.id
        GROUP BY s.product_id
        ORDER BY total_qty DESC
        LIMIT 5
      ''');

      final items = <AssistantItem>[];
      for (var row in topSellerResult) {
        final qty = (row['total_qty'] as num).toDouble();
        final rev = (row['total_revenue'] as num).toDouble();

        items.add(AssistantItem(
          title: row['name'] as String,
          subtitle: "Total Revenue: KES ${rev.toStringAsFixed(0)}",
          badgeText: "${qty.toStringAsFixed(0)} ${row['unit']} sold",
          badgeColor: Colors.amber.shade800,
        ));
      }

      return AssistantMessage(
        id: msgId,
        text: items.isEmpty
            ? "No sales data recorded yet to determine top sellers."
            : "Here are your top 5 best-selling products by volume:",
        isUser: false,
        timestamp: DateTime.now(),
        intent: 'TOP_SELLERS',
        items: items,
      );
    }

    // 7. INTENT: Expenses / Costs / Spending
    if (_matches(cleanQuery, ['expense', 'expenses', 'spent', 'spending', 'costs', 'ghrama', 'matumizi', 'bills', 'rent'])) {
      final expenseSummary = await db.rawQuery('''
        SELECT 
          COALESCE(SUM(amount), 0.0) as total_expenses,
          COUNT(*) as expense_count
        FROM expenses
        WHERE strftime('%Y-%m', date_time) = strftime('%Y-%m', 'now')
      ''');

      final recentExpenses = await db.rawQuery('''
        SELECT title, category, amount, date_time
        FROM expenses
        ORDER BY date_time DESC
        LIMIT 5
      ''');

      final totalExpMonth = (expenseSummary.first['total_expenses'] as num).toDouble();
      final count = (expenseSummary.first['expense_count'] as num).toInt();

      final items = <AssistantItem>[];
      for (var row in recentExpenses) {
        final amt = (row['amount'] as num).toDouble();
        final date = DateFormat('dd MMM').format(DateTime.parse(row['date_time'] as String));

        items.add(AssistantItem(
          title: row['title'] as String,
          subtitle: "${row['category']} • $date",
          badgeText: "KES ${amt.toStringAsFixed(0)}",
          badgeColor: Colors.redAccent,
        ));
      }

      return AssistantMessage(
        id: msgId,
        text: "Here is your expense summary for this month:",
        isUser: false,
        timestamp: DateTime.now(),
        intent: 'EXPENSES_BREAKDOWN',
        metrics: [
          AssistantMetric(label: "This Month's Costs", value: "KES ${totalExpMonth.toStringAsFixed(0)}", icon: Icons.receipt_long_outlined, color: Colors.redAccent),
          AssistantMetric(label: "Expense Entries", value: "$count", icon: Icons.list_alt_outlined, color: Colors.blue),
        ],
        items: items,
        actions: [
          AssistantAction(label: "Record New Expense", icon: Icons.add, actionType: AssistantActionType.openScreen, payload: {'screen': 'expenses'}),
        ],
      );
    }

    // 8. INTENT: Business Health / Store Diagnosis
    if (_matches(cleanQuery, ['health', 'score', 'diagnosis', 'advice', 'how is business', 'performance', 'hali ya biashara', 'tathmini'])) {
      final salesSummary = await db.rawQuery('''
        SELECT COALESCE(SUM(total_price), 0.0) as gross, COALESCE(SUM(profit), 0.0) as profit FROM sales
      ''');
      final debtSummary = await db.rawQuery('''
        SELECT COALESCE(SUM(debt_balance), 0.0) as total_debt FROM customers
      ''');
      final stockSummary = await db.rawQuery('''
        SELECT COUNT(*) as total_items, SUM(CASE WHEN stock_qty <= 0 THEN 1 ELSE 0 END) as out_of_stock FROM products
      ''');

      final gross = (salesSummary.first['gross'] as num).toDouble();
      final profit = (salesSummary.first['profit'] as num).toDouble();
      final debt = (debtSummary.first['total_debt'] as num).toDouble();
      final totalProducts = (stockSummary.first['total_items'] as num).toInt();
      final outOfStock = (stockSummary.first['out_of_stock'] as num).toInt();

      final marginPct = gross > 0 ? (profit / gross) * 100 : 0.0;
      final stockHealthPct = totalProducts > 0 ? ((totalProducts - outOfStock) / totalProducts) * 100 : 100.0;

      return AssistantMessage(
        id: msgId,
        text: "30-Second Store Diagnosis & Health Breakdown:",
        isUser: false,
        timestamp: DateTime.now(),
        intent: 'BUSINESS_HEALTH',
        metrics: [
          AssistantMetric(label: "Profit Margin", value: "${marginPct.toStringAsFixed(1)}%", icon: Icons.trending_up, color: marginPct >= 20 ? Colors.green : Colors.orange),
          AssistantMetric(label: "Stock In-Stock", value: "${stockHealthPct.toStringAsFixed(0)}%", icon: Icons.inventory_2_outlined, color: stockHealthPct >= 90 ? Colors.green : Colors.redAccent),
          AssistantMetric(label: "Debt Exposure", value: "KES ${debt.toStringAsFixed(0)}", icon: Icons.people_outline, color: debt > 10000 ? Colors.redAccent : Colors.blue),
        ],
        actions: [
          AssistantAction(label: "View 5-Pillar Health Score", icon: Icons.speed, actionType: AssistantActionType.openReports),
        ],
      );
    }

    // 9. FALLBACK / GENERAL STORE HELP
    return AssistantMessage(
      id: msgId,
      text: "I didn't quite understand that. Here are some quick questions you can ask me:",
      isUser: false,
      timestamp: DateTime.now(),
      intent: 'HELP',
      items: [
        AssistantItem(title: "Today's Sales & Profit", subtitle: "Ask: 'How much did I make today?'"),
        AssistantItem(title: "Active Customer Debtors", subtitle: "Ask: 'Who owes me money?'"),
        AssistantItem(title: "Low Stock & Reorders", subtitle: "Ask: 'Which items are out of stock?'"),
        AssistantItem(title: "Highest Margin Items", subtitle: "Ask: 'What are my most profitable goods?'"),
        AssistantItem(title: "Store Health Check", subtitle: "Ask: 'Give me a business health check'"),
      ],
      actions: [
        AssistantAction(label: "Today's Summary", icon: Icons.point_of_sale, actionType: AssistantActionType.openReports),
        AssistantAction(label: "Open POS", icon: Icons.shopping_cart_outlined, actionType: AssistantActionType.openPos),
      ],
    );
  }

  static bool _matches(String query, List<String> keywords) {
    for (var k in keywords) {
      if (query.contains(k)) return true;
    }
    return false;
  }
}
