import 'package:duka_manager/providers/auth_provider.dart';
import 'package:duka_manager/providers/shop_provider.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dashboard_tab.dart';
import 'inventory_screen.dart';
import 'pos_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import '../services/biometric_service.dart'; // 👈 Import Biometric Service

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  
  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  void _refreshStatus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final shop = Provider.of<ShopProvider>(context, listen: false);
      if (auth.isAuthenticated) {
        shop.loadSubscriptionStatus(auth.user?.uid);
      }
    });
  }

  final List<Widget> _pages = [
    DashboardTab(),
    InventoryScreen(),
    POSScreen(),
    ReportsScreen(),
    SettingsScreen(),
  ];

  // 🔒 SECURE NAVIGATION LOGIC
void _onItemTapped(int index) async {
  // 1. Get the current security preference from ShopProvider
  final shop = Provider.of<ShopProvider>(context, listen: false);

  // 2. Define restricted indices: 3 = Reports, 4 = Settings
  bool isRestricted = (index == 3 || index == 4);

  // 3. Logic: If page is restricted AND security toggle is ON, then authenticate
  if (isRestricted && shop.isSecurityEnabled) {
    bool authenticated = await BiometricService.authenticate();
    
    if (authenticated) {
      setState(() {
        _selectedIndex = index;
      });
    } else {
      // Show "Access Denied" if scan fails or is canceled
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Authentication Required", style: GoogleFonts.poppins()),
            backgroundColor: Colors.red,
            duration: const Duration(milliseconds: 1500),
          )
        );
      }
    }
  } else {
    // 4. Normal Navigation (if page is not restricted OR security is disabled)
    setState(() {
      _selectedIndex = index;
    });
  }
}

  // Theme Colors
  static const Color primaryOrange = Color(0xFFFF6B00);
  static const Color navTextUnselected = Color(0xFFBDBDBD);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, 
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.symmetric(vertical: 0),
        margin: EdgeInsets.fromLTRB(20, 0, 20, 25), 
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30), 
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 30,
              offset: Offset(0, 10),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BottomNavigationBar(
            backgroundColor: Colors.white,
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            showSelectedLabels: true,
            showUnselectedLabels: false, 
            selectedLabelStyle: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600),
            unselectedLabelStyle: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w500),
            selectedItemColor: primaryOrange,
            unselectedItemColor: navTextUnselected,
            currentIndex: _selectedIndex,
            onTap: _onItemTapped, // 👈 Intercepted here
            items: [
              BottomNavigationBarItem(
                icon: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Icon(Icons.dashboard_rounded),
                ),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Icon(Icons.inventory_2_outlined),
                ),
                activeIcon: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Icon(Icons.inventory_2_rounded),
                ),
                label: 'Stock',
              ),
              
              // THE "SELL" BUTTON (Highlighted Center)
              BottomNavigationBarItem(
                icon: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _selectedIndex == 2 ? primaryOrange : Colors.black, 
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: primaryOrange.withOpacity(0.3), blurRadius: 10, offset: Offset(0, 5))
                    ]
                  ),
                  child: Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 22),
                ),
                label: '', 
              ),

              BottomNavigationBarItem(
                icon: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Icon(Icons.analytics_outlined),
                ),
                 activeIcon: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Icon(Icons.analytics_rounded),
                ),
                label: 'Reports',
              ),
              BottomNavigationBarItem(
                icon: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Icon(Icons.settings_outlined),
                ),
                 activeIcon: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Icon(Icons.settings),
                ),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }
}