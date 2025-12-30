import 'package:duka_manager/providers/shop_provider.dart';
import 'package:duka_manager/screens/customers_screen.dart';
import 'package:duka_manager/screens/wallet_screen.dart';
import 'package:duka_manager/services/biometric_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/report_provider.dart';
import '../providers/inventory_provider.dart';
import 'add_product_screen.dart';
import 'pos_screen.dart';
import 'settings_screen.dart';
import '../providers/wallet_provider.dart';

class DashboardTab extends StatefulWidget {
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
    Provider.of<ShopProvider>(context, listen: false).refreshProStatus();
    await Provider.of<ReportProvider>(context, listen: false).loadDashboardStats();
    await Provider.of<InventoryProvider>(context, listen: false).loadProducts();
    final shopId = Provider.of<ShopProvider>(context, listen: false).shopId;
    Provider.of<WalletProvider>(context, listen: false).startBalanceListener(shopId);
  }

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

    // 🎨 YOUR THEME COLORS
    const Color primaryOrange = Color(0xFFFF6B00);
    const Color textDark = Color(0xFF1A1A1A);
    const Color cardGray = Color(0xFFF5F6F9);
    const Color bgWhite = Color(0xFFFFFFFF);

    return Scaffold(
      backgroundColor: cardGray, // Matches your theme's grey background
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: primaryOrange,
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, 60, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Header
              Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(getGreeting(), style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600)),
        Row(
          children: [
            Text(
              shop.shopName,
              style: GoogleFonts.poppins(
                fontSize: 22, 
                fontWeight: FontWeight.bold, 
                color: textDark
              )
            ),
            const SizedBox(width: 8),
            // 🚀 PRO / FREE BADGE
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: shop.isProActive ? Colors.green : Colors.grey.shade400,
                borderRadius: BorderRadius.circular(5)
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
        // ⏳ EXPIRY TEXT (Only shows if they are a Pro user)
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
                      padding: EdgeInsets.all(2),
                      decoration: BoxDecoration(color: primaryOrange, shape: BoxShape.circle),
                      child: Container(
                        height: 45, width: 45,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          image: DecorationImage(image: NetworkImage("https://ui-avatars.com/api/?name=${shop.shopName}&background=1A1A1A&color=fff"), fit: BoxFit.cover)
                        ),
                      ),
                    ),
                  )
                ],
              ),
              SizedBox(height: 25),

              // 2. Hero Card (The "Bizna Card" in Orange)
              _buildCreativeHeroCard(totalStockValue, primaryOrange),
              
              SizedBox(height: 25),
              GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => WalletScreen())),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 4))
                ],
              ),
              child: Row(
                children: [
                  // Icon with soft background
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Color(0xFFFF6B00).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.account_balance_wallet, color: Color(0xFFFF6B00), size: 24),
                  ),
                  SizedBox(width: 15),
                  // Text Info
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("App Balance", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                      Text(
                        "KES ${wallet.balance.toStringAsFixed(2)}", 
                        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))
                      ),
                    ],
                  ),
                  Spacer(),
                  // Top Up Action Text
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "Top Up", 
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)
                    ),
                  )
                ],
              ),
            ),
          ),

          SizedBox(height: 25),

              // 3. Stats Row (Clean White Pills)
              Row(
                children: [
                  _buildStatPill("Total Items", "$totalItems", textDark, bgWhite, Icons.widgets_outlined),
                  SizedBox(width: 15),
                  _buildStatPill("Stockout", "$outOfStock", Colors.redAccent, bgWhite, Icons.warning_amber_rounded),
                  SizedBox(width: 15),
                  _buildStatPill("Low Stock", "${reports.lowStockItems}", primaryOrange, bgWhite, Icons.trending_down),
                ],
              ),
              
              SizedBox(height: 30),

              // 4. Quick Actions (Bento Grid)
              Text("Quick Actions", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: textDark)),
              SizedBox(height: 15),
              
              // Use IntrinsicHeight to prevent overflow errors
              IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Big POS Button (Dark for contrast)
                Expanded(
                  flex: 6,
                  child: _buildBentoAction(
                    title: "POS Terminal",
                    subtitle: "New Sale",
                    icon: Icons.qr_code_scanner,
                    bgColor: textDark,       // Dark card
                    textColor: Colors.white, // White text
                    iconColor: primaryOrange,// Orange icon
                    isTall: true,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => POSScreen())),
                  ),
                ),
                SizedBox(width: 15),
                // Stacked Smaller Buttons
                Expanded(
                  flex: 4,
                  child: Column(
                    children: [
                      Expanded(
                        child: _buildBentoAction(
                          title: "Add Item",
                          subtitle: "",
                          icon: Icons.add,
                          bgColor: bgWhite,
                          textColor: textDark,
                          iconColor: primaryOrange,
                          isTall: false,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => AddProductScreen())),
                        ),
                      ),
                      SizedBox(height: 15),
                      // 👇 UPDATED: Deni Manager Button
                      Expanded(
                        child: _buildBentoAction(
                          title: "Deni Manager",
                          subtitle: "Track Debt",
                          icon: Icons.people_alt_outlined,
                          bgColor: bgWhite,
                          textColor: textDark,
                          iconColor: Colors.blue, // Distinct Blue Color
                          isTall: false,
                          onTap: () async {
  final shop = Provider.of<ShopProvider>(context, listen: false);
  
  bool canAccess = false;

  if (shop.isSecurityEnabled) {
    // 🛡️ LOCK IS ON: Run Biometric/PIN check
    canAccess = await BiometricService.authenticate();
  } else {
    // 🔓 LOCK IS OFF: Direct entry
    canAccess = true;
  }

  if (canAccess) {
    Navigator.push(context, MaterialPageRoute(builder: (c) => CustomersScreen()));
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Authentication Required to view debts"))
    );
  }
},
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
              SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // 🎨 WIDGET: Creative Hero Card (Orange Gradient)
  Widget _buildCreativeHeroCard(double value, Color primaryColor) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(25),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          // Your Theme Gradient: Orange to lighter Orange
          colors: [primaryColor, Color(0xFFFF9E40)], 
        ),
        boxShadow: [
          BoxShadow(color: primaryColor.withOpacity(0.4), blurRadius: 20, offset: Offset(0, 10)),
        ],
      ),
      child: Stack(
        children: [
          // Decorative Circles
          Positioned(
            top: -50, right: -50,
            child: Container(width: 150, height: 150, decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Total Asset Value", style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.9), fontSize: 14, fontWeight: FontWeight.w500)),
                  Icon(Icons.show_chart, color: Colors.white, size: 20),
                ],
              ),
              SizedBox(height: 15),
              Text(
                "KES ${value.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}",
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                child: Text("Live Updates", style: GoogleFonts.poppins(color: Colors.white, fontSize: 10)),
              )
            ],
          ),
        ],
      ),
    );
  }

  // 💊 WIDGET: Stat Pill
  Widget _buildStatPill(String label, String value, Color iconColor, Color bgColor, IconData icon) {
    return Expanded(
      child: Container(
        height: 110,
        padding: EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 5))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 24),
            Spacer(),
            Text(value, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
            Text(label, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  // 🍱 WIDGET: Bento Grid Card (Flexible)
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
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 15, offset: Offset(0, 5)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Icon(icon, color: iconColor, size: 28),
            ),
            // Spacers allow content to spread in tall cards, but compact in small ones
            if (isTall) Spacer(), 
            if (isTall) SizedBox(height: 10),
            
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
                if (subtitle.isNotEmpty)
                  Text(subtitle, style: GoogleFonts.poppins(fontSize: 12, color: textColor.withOpacity(0.6))),
              ],
            )
          ],
        ),
      ),
    );
  }
}