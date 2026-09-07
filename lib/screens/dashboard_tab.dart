import 'package:duka_manager/providers/shop_provider.dart';
import 'package:duka_manager/screens/customers_screen.dart';
import 'package:duka_manager/screens/expense_screen.dart';
import 'package:duka_manager/screens/wallet_screen.dart';
import 'package:duka_manager/services/biometric_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/report_provider.dart';
import '../providers/inventory_provider.dart';
import 'add_product_screen.dart';
import 'pos_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import 'close_day_screen.dart';
import 'suppliers_screen.dart';
import 'assistant_screen.dart';
import 'subscription_screen.dart';
import '../providers/wallet_provider.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  _DashboardTabState createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final shop = Provider.of<ShopProvider>(context, listen: false);
    await shop.refreshProStatus();
    if (!mounted) return;
    await Provider.of<ReportProvider>(context, listen: false).loadDashboardStats();
    if (!mounted) return;
    await Provider.of<InventoryProvider>(context, listen: false).loadProducts(isPro: shop.isProActive);
    if (!mounted) return;
    final shopId = shop.shopId;
    Provider.of<WalletProvider>(context, listen: false).startBalanceListener(shopId);
  }

  // THEME COLORS
  Color get _primaryOrange => const Color(0xFFFF6B00);
  Color get _surfaceColor => Theme.of(context).colorScheme.surface;
  Color get _containerColor => Theme.of(context).brightness == Brightness.light ? const Color(0xFFF5F6F9) : const Color(0xFF121212);
  Color get _cardColor => Theme.of(context).brightness == Brightness.light ? Colors.white : const Color(0xFF1E1E1E);
  Color get _textColor => Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF1A1A1A);

  String getGreeting() {
    var hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning,';
    if (hour < 17) return 'Good Afternoon,';
    return 'Good Evening,';
  }

  @override
  Widget build(BuildContext context) {
    final reports = Provider.of<ReportProvider>(context);
    final inventory = Provider.of<InventoryProvider>(context);
    final wallet = Provider.of<WalletProvider>(context);
    final shop = Provider.of<ShopProvider>(context);

    // Live Calculations
    double totalStockValue = inventory.products.fold(0, (sum, item) => sum + (item.buyPrice * item.stockQty));
    int totalItems = inventory.products.length;
    int outOfStock = inventory.products.where((i) => i.stockQty == 0).length;

    return Scaffold(
      backgroundColor: _containerColor,
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: _primaryOrange,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 55, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header with greeting and profile
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(getGreeting(), style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600)),
                      Row(
                        children: [
                          Text(
                            shop.shopName,
                            style: GoogleFonts.poppins(
                              fontSize: 22, 
                              fontWeight: FontWeight.bold, 
                              color: _textColor
                            )
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: shop.isProActive ? Colors.green : Colors.grey.shade400,
                              borderRadius: BorderRadius.circular(6)
                            ),
                            child: Text(
                              shop.isProActive ? "PRO" : "FREE",
                              style: const TextStyle(
                                color: Colors.white, 
                                fontSize: 10, 
                                fontWeight: FontWeight.bold
                              ),
                            ),
                          )
                        ],
                      ),
                      if (shop.isProActive)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            "Pro active: ${shop.daysRemaining} days left", 
                            style: GoogleFonts.poppins(
                              fontSize: 11, 
                              fontWeight: FontWeight.w500, 
                              color: Colors.green.shade700
                            )
                          ),
                        ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => SettingsScreen())),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(color: _primaryOrange, shape: BoxShape.circle),
                      child: Container(
                        height: 44, width: 44,
                        decoration: BoxDecoration(
                          color: _cardColor,
                          shape: BoxShape.circle,
                          image: DecorationImage(
                            image: NetworkImage("https://ui-avatars.com/api/?name=${shop.shopName}&background=1A1A1A&color=fff"), 
                            fit: BoxFit.cover
                          )
                        ),
                      ),
                    ),
                  )
                ],
              ),
              
              const SizedBox(height: 16),

              // 1.5 SMART ASSISTANT INTERACTIVE HERO BAR
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AssistantScreen())),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _primaryOrange.withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _primaryOrange.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.smart_toy_outlined, color: _primaryOrange, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Ask M-Bizna Smart Assistant",
                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: _textColor),
                            ),
                            Text(
                              "Sales, profit, top debtors, low stock...",
                              style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, size: 14, color: _primaryOrange),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 2. DAILY COMMAND CENTER CARD
              _buildDailyCommandCenter(reports, shop.isOwner),

              const SizedBox(height: 18),

              // 3. SMART BUSINESS INSIGHTS
              _buildSmartInsightsSection(reports),

              const SizedBox(height: 20),

              // 4. Quick Key Metrics Pills
              Row(
                children: [
                  _buildStatPill("Total Items", "$totalItems", _textColor, _cardColor, Icons.inventory_2_outlined),
                  const SizedBox(width: 12),
                  _buildStatPill("Stockout", "$outOfStock", Colors.redAccent, _cardColor, Icons.warning_amber_rounded),
                  const SizedBox(width: 12),
                  _buildStatPill("Low Stock", "${reports.lowStockItems}", _primaryOrange, _cardColor, Icons.trending_down),
                ],
              ),

              const SizedBox(height: 20),

              // 5. Subscription Status & Valuation Bar
              Row(
                children: [
                  // M-Bizna Pro Subscription Card
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const SubscriptionScreen())),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _cardColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: (shop.isProActive ? Colors.green : _primaryOrange).withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                shop.isProActive ? Icons.verified : Icons.workspace_premium,
                                color: shop.isProActive ? Colors.green : _primaryOrange,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Plan Status", style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
                                  Text(
                                    shop.isProActive ? "Pro Active" : "Free Plan", 
                                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: shop.isProActive ? Colors.green : _textColor)
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios, color: _primaryOrange, size: 14),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  if (shop.isOwner) ...[
                    const SizedBox(width: 12),
                    // Asset Valuation
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _cardColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.storefront_outlined, color: Colors.blue, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Stock Value", style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
                                  Text(
                                    shop.isProActive
                                      ? "KES ${totalStockValue.toStringAsFixed(0)}"
                                      : "KES ***",
                                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: _textColor)
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ]
                ],
              ),

              const SizedBox(height: 25),

              // 6. Quick Actions (Bento Grid)
              Text("Quick Actions", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: _textColor)),
              const SizedBox(height: 14),
              
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Big POS Terminal Action
                    Expanded(
                      flex: 6,
                      child: _buildBentoAction(
                        title: "POS Terminal",
                        subtitle: "New Sale",
                        icon: Icons.qr_code_scanner,
                        bgColor: Theme.of(context).brightness == Brightness.light ? const Color(0xFF1A1A1A) : const Color(0xFF2C2C2C), 
                        textColor: Colors.white,
                        iconColor: _primaryOrange,
                        isTall: true,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const POSScreen())),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Stacked Shortcuts
                    Expanded(
                      flex: 4,
                      child: Column(
                        children: [
                          Expanded(
                            child: _buildBentoAction(
                              title: "Add Item",
                              subtitle: "Catalog",
                              icon: Icons.add_circle_outline,
                              bgColor: _cardColor,
                              textColor: _textColor,
                              iconColor: _primaryOrange,
                              isTall: false,
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => AddProductScreen())),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (shop.isOwner)
                            Expanded(
                              child: _buildBentoAction(
                                title: "Deni Book",
                                subtitle: "Credit Debt",
                                icon: Icons.people_alt_outlined,
                                bgColor: _cardColor,
                                textColor: _textColor,
                                iconColor: Colors.blue, 
                                isTall: false,
                                onTap: () async {
                                  bool canAccess = shop.isSecurityEnabled ? await BiometricService.authenticate() : true;
                                  if (canAccess) Navigator.push(context, MaterialPageRoute(builder: (c) => CustomersScreen()));
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              if (shop.isOwner)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _buildBentoAction(
                          title: "Expenses",
                          subtitle: shop.isProActive ? "Record Cost" : "Pro Feature",
                          icon: Icons.receipt_long_outlined,
                          bgColor: _cardColor,
                          textColor: shop.isProActive ? _textColor : Colors.grey,
                          iconColor: shop.isProActive ? Colors.redAccent : Colors.grey,
                          isTall: false,
                          onTap: () {
                            if (shop.isProActive) {
                              Navigator.push(context, MaterialPageRoute(builder: (c) => const ExpenseScreen()));
                            } else {
                              _showSubscriptionRequiredDialog();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildBentoAction(
                          title: "Analytics",
                          subtitle: "Reports & PDF",
                          icon: Icons.bar_chart_outlined,
                          bgColor: _cardColor,
                          textColor: _textColor,
                          iconColor: Colors.green,
                          isTall: false,
                          onTap: () async {
                            bool canAccess = shop.isSecurityEnabled ? await BiometricService.authenticate() : true;
                            if (canAccess) Navigator.push(context, MaterialPageRoute(builder: (c) => const ReportsScreen()));
                          },
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 12),

              if (shop.isOwner)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _buildBentoAction(
                          title: "Suppliers",
                          subtitle: "Restock Orders",
                          icon: Icons.local_shipping_outlined,
                          bgColor: _cardColor,
                          textColor: _textColor,
                          iconColor: Colors.teal,
                          isTall: false,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SuppliersScreen())),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildBentoAction(
                          title: "Close Day",
                          subtitle: "Z-Report",
                          icon: Icons.lock_clock_outlined,
                          bgColor: _cardColor,
                          textColor: _textColor,
                          iconColor: _primaryOrange,
                          isTall: false,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CloseDayScreen())),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // WIDGET: Daily Command Center Card
  Widget _buildDailyCommandCenter(ReportProvider reports, bool isOwner) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _primaryOrange,
            const Color(0xFFFF8B33),
          ],
        ),
        boxShadow: [
          BoxShadow(color: _primaryOrange.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.insights, color: Colors.white, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    "TODAY'S COMMAND CENTER", 
                    style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.9), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.2)
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                child: Text(
                  "${reports.todayTransactionsCount} sales",
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)
                ),
              )
            ],
          ),
          
          const SizedBox(height: 16),
          
          Text(
            isOwner ? "Net Profit Today" : "Total Sales Today",
            style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.85), fontSize: 13)
          ),
          const SizedBox(height: 4),
          Text(
            isOwner
              ? "KES ${reports.todayNetProfit.toStringAsFixed(0)}"
              : "KES ${reports.todaySales.toStringAsFixed(0)}",
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          
          const SizedBox(height: 16),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 14),

          // Sub-metrics (Sales, Expenses, Avg Basket)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildCommandSubMetric(
                label: "Gross Sales",
                value: "KES ${reports.todaySales.toStringAsFixed(0)}",
                icon: Icons.point_of_sale,
              ),
              _buildCommandSubMetric(
                label: "Expenses",
                value: "KES ${reports.todayExpenses.toStringAsFixed(0)}",
                icon: Icons.receipt_long_outlined,
              ),
              _buildCommandSubMetric(
                label: "Avg Basket",
                value: "KES ${reports.averageBasketSize.toStringAsFixed(0)}",
                icon: Icons.shopping_basket_outlined,
              ),
            ],
          ),

          if (isOwner) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _primaryOrange,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                icon: const Icon(Icons.lock_clock, size: 16, color: Color(0xFFFF6B00)),
                label: Text(
                  "Close Business Day (Z-Report)",
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFFF6B00)),
                ),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CloseDayScreen())),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCommandSubMetric({required String label, required String value, required IconData icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white70, size: 13),
            const SizedBox(width: 4),
            Text(label, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 2),
        Text(value, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  // WIDGET: Smart Business Insights Cards
  Widget _buildSmartInsightsSection(ReportProvider reports) {
    final insights = <Widget>[];

    // Insight 1: Top Seller
    if (reports.topSellingProductName != null && reports.topSellingProductQty > 0) {
      insights.add(
        _buildInsightItem(
          icon: Icons.star_outline,
          iconColor: Colors.amber,
          title: "Top Seller Today",
          detail: "${reports.topSellingProductName} (${reports.topSellingProductQty.toStringAsFixed(0)} units sold)",
        ),
      );
    }

    // Insight 2: Critical Stock Alert
    if (reports.criticalStockName != null && reports.criticalStockQty > 0) {
      insights.add(
        _buildInsightItem(
          icon: Icons.warning_amber_rounded,
          iconColor: Colors.redAccent,
          title: "Critical Stock Alert",
          detail: "${reports.criticalStockName} has only ${reports.criticalStockQty.toStringAsFixed(0)} units left in stock.",
        ),
      );
    }

    // Insight 3: Outstanding Deni
    if (reports.totalOutstandingDebt > 0) {
      insights.add(
        _buildInsightItem(
          icon: Icons.people_outline,
          iconColor: Colors.blue,
          title: "Deni Customer Ledger",
          detail: "${reports.debtorCount} customers owe KES ${reports.totalOutstandingDebt.toStringAsFixed(0)} total.",
        ),
      );
    }

    // Insight 4: Sales Trend vs Yesterday
    if (reports.todaySales > 0 && reports.salesGrowthPercentage != 0) {
      final isUp = reports.salesGrowthPercentage > 0;
      insights.add(
        _buildInsightItem(
          icon: isUp ? Icons.trending_up : Icons.trending_down,
          iconColor: isUp ? Colors.green : Colors.orange,
          title: "Sales Momentum",
          detail: "Today's sales are ${isUp ? '+' : ''}${reports.salesGrowthPercentage.toStringAsFixed(0)}% compared to yesterday.",
        ),
      );
    }

    if (insights.isEmpty) {
      insights.add(
        _buildInsightItem(
          icon: Icons.info_outline,
          iconColor: _primaryOrange,
          title: "Business Ready",
          detail: "Record your first sale of the day to start generating real-time performance insights.",
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.lightbulb_outline, size: 18, color: _primaryOrange),
            const SizedBox(width: 6),
            Text("Business Insights", style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: _textColor)),
          ],
        ),
        const SizedBox(height: 10),
        ...insights,
      ],
    );
  }

  Widget _buildInsightItem({
    required IconData icon, 
    required Color iconColor, 
    required String title, 
    required String detail
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: _textColor)),
                Text(detail, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // WIDGET: Stat Pill
  Widget _buildStatPill(String label, String value, Color iconColor, Color bgColor, IconData icon) {
    return Expanded(
      child: Container(
        height: 95,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 20),
            const Spacer(),
            Text(value, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: _textColor)),
            Text(label, style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  // WIDGET: Bento Grid Card
  Widget _buildBentoAction({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color bgColor,
    required Color textColor,
    required Color iconColor,
    required bool isTall,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Icon(icon, color: iconColor, size: 26),
            ),
            if (isTall) const Spacer(), 
            if (isTall) const SizedBox(height: 10),
            
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: textColor)),
                if (subtitle.isNotEmpty)
                  Text(subtitle, style: GoogleFonts.poppins(fontSize: 11, color: textColor.withOpacity(0.6))),
              ],
            )
          ],
        ),
      ),
    );
  }

  void _showSubscriptionRequiredDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Upgrade to Pro", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text("Cloud Sync, Advanced Reports, and Expense Tracking require a KES 200/mo subscription."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Maybe Later")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B00)),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (c) => SettingsScreen()));
            },
            child: const Text("View Plans", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

