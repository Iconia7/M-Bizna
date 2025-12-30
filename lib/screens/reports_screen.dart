import 'package:duka_manager/db/database_helper.dart';
import 'package:duka_manager/services/pdf_service.dart';
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
  // 🎨 THEME COLORS
  static const Color primaryOrange = Color(0xFFFF6B00);
  static const Color textDark = Color(0xFF1A1A1A);
  static const Color cardGray = Color(0xFFF5F6F9);

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
      backgroundColor: cardGray,
      appBar: AppBar(
        backgroundColor: cardGray,
        elevation: 0,
        centerTitle: false,
        title: Text("Analytics", style: GoogleFonts.poppins(color: textDark, fontWeight: FontWeight.bold, fontSize: 24)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: textDark),
            onPressed: () => Provider.of<ReportProvider>(context, listen: false).loadDashboardStats(),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.print, color: textDark),
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
                  color: textDark,
                  textColor: Colors.white,
                  iconColor: primaryOrange,
                ),
                SizedBox(width: 15),
                _buildSummaryCard(
                  title: "Total Sales",
                  value: "KES ${reports.todaySales.toStringAsFixed(0)}",
                  icon: Icons.attach_money,
                  color: Colors.white,
                  textColor: textDark,
                  iconColor: textDark,
                ),
              ],
            ),
            
            SizedBox(height: 25),

            // 2. Real Weekly Chart
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: Offset(0, 5))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Weekly Revenue", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: textDark)),
                  SizedBox(height: 25),
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
            Text("Recent Sales", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: textDark)),
            SizedBox(height: 15),

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
                  separatorBuilder: (ctx, i) => SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final tx = transactions[i];
                    return Container(
                      padding: EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.03), blurRadius: 10, offset: Offset(0, 4))]
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(color: cardGray, shape: BoxShape.circle),
                            child: Icon(Icons.receipt_long, color: textDark, size: 20),
                          ),
                          SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(tx['name'], style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15, color: textDark), overflow: TextOverflow.ellipsis),
                                Text("${tx['quantity']} items • ${tx['time']}", style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          ),
                          Text(
                            "+${(tx['amount'] as double).toStringAsFixed(0)}", 
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)
                          ),
                        ],
                      ),
                    );
                  },
                ),
            
            SizedBox(height: 100), // Bottom padding
          ],
        ),
      ),
    );
  }

  // Summary Card Widget
  Widget _buildSummaryCard({required String title, required String value, required IconData icon, required Color color, required Color textColor, required Color iconColor}) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: Offset(0, 5))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(color: textColor == Colors.white ? Colors.white.withOpacity(0.2) : cardGray, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            SizedBox(height: 20),
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
        Container(
          height: 120, width: 12,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Container(decoration: BoxDecoration(color: cardGray, borderRadius: BorderRadius.circular(10))),
              FractionallySizedBox(
                heightFactor: safeHeight,
                child: Container(
                  decoration: BoxDecoration(
                    color: isHigh ? primaryOrange : textDark.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: isHigh ? [BoxShadow(color: primaryOrange.withOpacity(0.4), blurRadius: 8, offset: Offset(0, 2))] : [],
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 10),
        Text(label, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}