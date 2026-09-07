import 'package:duka_manager/db/database_helper.dart';
import 'package:duka_manager/providers/inventory_provider.dart';
import 'package:duka_manager/providers/sales_provider.dart';
import 'package:duka_manager/services/pdf_service.dart';
import 'package:duka_manager/widgets/feedback_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/report_provider.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  _ReportsScreenState createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  // 🎨 THEME COLORS (Dynamic Getters)
  Color get _primaryOrange => const Color(0xFFFF6B00);
  Color get _surfaceColor => Theme.of(context).colorScheme.surface;
  Color get _containerColor => Theme.of(context).brightness == Brightness.light ? const Color(0xFFF5F6F9) : const Color(0xFF121212);
  Color get _cardColor => Theme.of(context).brightness == Brightness.light ? Colors.white : const Color(0xFF1E1E1E);
  Color get _textColor => Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF1A1A1A);

  @override
  void initState() {
    super.initState();
    Provider.of<ReportProvider>(context, listen: false).loadDashboardStats();
  }

  Future<void> _exportReport(String type) async {
    // 1. Determine Date Range
    DateTime now = DateTime.now();
    DateTime start;
    String title;

    if (type == 'week') {
      start = now.subtract(Duration(days: 7));
      title = "Last 7 Days";
    } else {
      start = DateTime(now.year, now.month, 1); // Start of month
      title = "This Month";
    }

    // 2. Fetch Detailed Data (Move this logic to Provider in Phase 3, keeping here for simplicity now)
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery('''
      SELECT s.date_time, p.name, s.quantity, s.total_price 
      FROM sales s
      JOIN products p ON s.product_id = p.id
      WHERE s.date_time >= ?
      ORDER BY s.date_time DESC
    ''', [start.toIso8601String()]);

    // 3. Calculate Totals
    double totalRev = 0;
    // Note: Profit requires joining buy_price, simplified here to just revenue for PDF demo
    for (var row in result) {
      totalRev += (row['total_price'] as double);
    }

    // 4. Generate PDF
    if (result.isNotEmpty) {
      await PdfService().generateSalesReport(result, totalRev, totalRev * 0.3, title); // 30% profit estimate
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("No data to export")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final reports = Provider.of<ReportProvider>(context);
    final transactions = reports.recentTransactions;
    final weeklyData = reports.weeklySales;

    // Find max value for bar chart scaling
    double maxVal = weeklyData.reduce((curr, next) => curr > next ? curr : next);
    if (maxVal == 0) maxVal = 1; // Prevent division by zero

    return Scaffold(
      backgroundColor: _containerColor,
      appBar: AppBar(
        backgroundColor: _containerColor,
        elevation: 0,
        centerTitle: false,
        title: Text("Analytics", style: GoogleFonts.poppins(color: _textColor, fontWeight: FontWeight.bold, fontSize: 24)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: _textColor),
            onPressed: () => Provider.of<ReportProvider>(context, listen: false).loadDashboardStats(),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.print, color: _textColor),
            onSelected: _exportReport,
            itemBuilder: (ctx) => [
              PopupMenuItem(value: 'week', child: Text("Print Weekly Report")),
              PopupMenuItem(value: 'month', child: Text("Print Monthly Report")),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Summary Cards
            Row(
              children: [
                _buildSummaryCard(
                  title: "Total Profit",
                  value: "KES ${reports.todayProfit.toStringAsFixed(0)}",
                  icon: Icons.trending_up,
                  color: Theme.of(context).brightness == Brightness.light ? const Color(0xFF1A1A1A) : const Color(0xFF444444),
                  textColor: Colors.white,
                  iconColor: _primaryOrange,
                ),
                const SizedBox(width: 15),
                _buildSummaryCard(
                  title: "Total Sales",
                  value: "KES ${reports.todaySales.toStringAsFixed(0)}",
                  icon: Icons.attach_money,
                  color: _cardColor,
                  textColor: _textColor,
                  iconColor: _textColor,
                ),
              ],
            ),
            
            const SizedBox(height: 20),

            // 2. Business Health Score Card (5-Pillar Algorithmic Assessment)
            _buildBusinessHealthCard(reports.businessHealth),

            const SizedBox(height: 20),

            // 3. Real Weekly Chart
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Weekly Revenue", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: _textColor)),
                  const SizedBox(height: 25),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildBar("Mon", (weeklyData[0] / maxVal), weeklyData[0] == maxVal),
                      _buildBar("Tue", (weeklyData[1] / maxVal), weeklyData[1] == maxVal),
                      _buildBar("Wed", (weeklyData[2] / maxVal), weeklyData[2] == maxVal),
                      _buildBar("Thu", (weeklyData[3] / maxVal), weeklyData[3] == maxVal),
                      _buildBar("Fri", (weeklyData[4] / maxVal), weeklyData[4] == maxVal),
                      _buildBar("Sat", (weeklyData[5] / maxVal), weeklyData[5] == maxVal),
                      _buildBar("Sun", (weeklyData[6] / maxVal), weeklyData[6] == maxVal),
                    ],
                  )
                ],
              ),
            ),

            SizedBox(height: 25),

            // 3. Real Recent Transactions
            Text("Recent Sales", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: _textColor)),
            const SizedBox(height: 15),

            transactions.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text("No sales today", style: GoogleFonts.poppins(color: Colors.grey)),
                  ),
                )
              : ListView.separated(
                  physics: NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: transactions.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final tx = transactions[i];
                    return GestureDetector(
                      onTap: () => _showTransactionActions(tx),
                      child: Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: _cardColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: _containerColor, shape: BoxShape.circle),
                              child: Icon(Icons.receipt_long, color: _textColor, size: 20),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(tx['name'], style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15, color: _textColor), overflow: TextOverflow.ellipsis),
                                  Text("${tx['quantity']} items • ${tx['time']}", style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  "+KES ${(tx['amount'] as double).toStringAsFixed(0)}", 
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green)
                                ),
                                Text(
                                  "Tap to return",
                                  style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            
            const SizedBox(height: 100), // Bottom padding
          ],
        ),
      ),
    );
  }

  void _showTransactionActions(Map<String, dynamic> tx) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
            ),
            const SizedBox(height: 16),
            Text(tx['name'], style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: _textColor)),
            Text("Sold: ${tx['quantity']} units for KES ${(tx['amount'] as double).toStringAsFixed(0)} at ${tx['time']}", style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 20),

            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.12), shape: BoxShape.circle),
                child: const Icon(Icons.assignment_return_outlined, color: Colors.redAccent),
              ),
              title: Text("Process Return / Refund", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: _textColor, fontSize: 14)),
              subtitle: Text("Restock item into inventory and issue refund", style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
              onTap: () {
                Navigator.pop(ctx);
                _showProcessReturnDialog(tx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showProcessReturnDialog(Map<String, dynamic> tx) {
    final saleId = tx['id'] as int;
    final productId = tx['product_id'] as int? ?? 1;
    final maxQty = (tx['quantity'] as num).toDouble();
    final totalAmount = (tx['amount'] as num).toDouble();

    final qtyCtrl = TextEditingController(text: maxQty > 1 ? "1" : maxQty.toStringAsFixed(0));
    final refundCtrl = TextEditingController(text: (totalAmount / (maxQty > 0 ? maxQty : 1)).toStringAsFixed(0));
    String selectedReason = "Damaged / Defective";

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          backgroundColor: _surfaceColor,
          title: Row(
            children: [
              const Icon(Icons.assignment_return_outlined, color: Colors.redAccent, size: 22),
              const SizedBox(width: 8),
              Text("Process Return", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: _textColor)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Item: ${tx['name']}", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: _textColor, fontSize: 14)),
                Text("Original Quantity Sold: $maxQty", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 16),

                TextField(
                  controller: qtyCtrl,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.poppins(color: _textColor),
                  decoration: const InputDecoration(
                    labelText: "Quantity Returned",
                    prefixIcon: Icon(Icons.numbers, size: 18),
                  ),
                  onChanged: (val) {
                    final q = double.tryParse(val) ?? 1.0;
                    final unitPrice = totalAmount / (maxQty > 0 ? maxQty : 1);
                    refundCtrl.text = (q * unitPrice).toStringAsFixed(0);
                  },
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: refundCtrl,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.poppins(color: _textColor),
                  decoration: const InputDecoration(
                    labelText: "Refund Amount (KES)",
                    prefixIcon: Icon(Icons.payments_outlined, size: 18),
                  ),
                ),
                const SizedBox(height: 14),

                Text("Reason for Return:", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: selectedReason,
                  dropdownColor: _surfaceColor,
                  style: GoogleFonts.poppins(color: _textColor, fontSize: 13),
                  items: [
                    "Damaged / Defective",
                    "Expired Goods",
                    "Wrong Item Purchased",
                    "Customer Changed Mind",
                  ].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedReason = val);
                  },
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.help_outline, size: 18),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text("Cancel", style: GoogleFonts.poppins(color: Colors.grey)),
              onPressed: () => Navigator.pop(ctx),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text("Confirm & Restock", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () async {
                final retQty = double.tryParse(qtyCtrl.text) ?? 1.0;
                final refAmount = double.tryParse(refundCtrl.text) ?? 0.0;

                if (retQty > 0 && refAmount >= 0) {
                  final salesProvider = Provider.of<SalesProvider>(context, listen: false);
                  final inventoryProvider = Provider.of<InventoryProvider>(context, listen: false);
                  final reportProvider = Provider.of<ReportProvider>(context, listen: false);

                  final success = await salesProvider.processReturn(
                    saleId: saleId,
                    productId: productId,
                    returnQty: retQty,
                    refundAmount: refAmount,
                    reason: selectedReason,
                  );

                  if (success) {
                    await inventoryProvider.loadProducts();
                    await reportProvider.loadDashboardStats();
                    Navigator.pop(ctx);
                    FeedbackDialog.show(
                      context, 
                      title: "Return Complete", 
                      message: "Restocked $retQty units of ${tx['name']}.\nRefund of KES ${refAmount.toStringAsFixed(0)} issued.", 
                      isSuccess: true
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // Business Health Score Widget
  Widget _buildBusinessHealthCard(BusinessHealth health) {
    Color scoreColor;
    if (health.overallScore >= 75) {
      scoreColor = Colors.green;
    } else if (health.overallScore >= 50) {
      scoreColor = Colors.orange;
    } else {
      scoreColor = Colors.redAccent;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: scoreColor.withOpacity(0.12), shape: BoxShape.circle),
                    child: Icon(Icons.speed, color: scoreColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("BUSINESS HEALTH SCORE", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.1)),
                      Text("5-Pillar Operational Health", style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: _textColor)),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: scoreColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: scoreColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Text(
                      "${health.overallScore}",
                      style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: scoreColor),
                    ),
                    Text(
                      "/100",
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: scoreColor.withOpacity(0.8)),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 5-Pillar Score Breakdown
          _buildPillarRow("Sales Activity", health.salesScore, Icons.trending_up),
          const SizedBox(height: 10),
          _buildPillarRow("Profit Margin", health.profitScore, Icons.pie_chart_outline),
          const SizedBox(height: 10),
          _buildPillarRow("Inventory Health", health.inventoryScore, Icons.inventory_2_outlined),
          const SizedBox(height: 10),
          _buildPillarRow("Debt Risk", health.debtScore, Icons.people_outline),
          const SizedBox(height: 10),
          _buildPillarRow("Expense Control", health.expenseScore, Icons.receipt_long_outlined),

          const SizedBox(height: 18),

          // Actionable Advice Box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _containerColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _primaryOrange.withOpacity(0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline, color: _primaryOrange, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        health.adviceTitle,
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: _textColor),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        health.adviceMessage,
                        style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillarRow(String label, int score, IconData icon) {
    Color barColor = score >= 75 ? Colors.green : (score >= 50 ? Colors.orange : Colors.redAccent);

    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 8),
        SizedBox(
          width: 110,
          child: Text(label, style: GoogleFonts.poppins(fontSize: 12, color: _textColor, fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: score / 100.0,
              backgroundColor: _containerColor,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 32,
          child: Text(
            "$score",
            textAlign: TextAlign.end,
            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: _textColor),
          ),
        ),
      ],
    );
  }

  // Summary Card Widget
  Widget _buildSummaryCard({required String title, required String value, required IconData icon, required Color color, required Color textColor, required Color iconColor}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: textColor == Colors.white ? Colors.white.withOpacity(0.2) : _containerColor, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(height: 20),
            Text(value, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
            Text(title, style: GoogleFonts.poppins(fontSize: 12, color: textColor.withOpacity(0.6))),
          ],
        ),
      ),
    );
  }

  // Bar Chart Widget
  Widget _buildBar(String label, double heightFactor, bool isHigh) {
    // Ensure heightFactor is between 0.05 and 1.0 (so empty bars show a tiny blip)
    final double safeHeight = heightFactor < 0.05 ? 0.05 : heightFactor;
    
    return Column(
      children: [
        SizedBox(
          height: 120, width: 12,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Container(decoration: BoxDecoration(color: _containerColor, borderRadius: BorderRadius.circular(10))),
              FractionallySizedBox(
                heightFactor: safeHeight,
                child: Container(
                  decoration: BoxDecoration(
                    color: isHigh ? _primaryOrange : _textColor.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: isHigh ? [BoxShadow(color: _primaryOrange.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 2))] : [],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(label, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}