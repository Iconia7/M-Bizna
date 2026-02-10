
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:duka_manager/db/database_helper.dart';
import 'package:duka_manager/providers/wallet_provider.dart';
import 'package:duka_manager/screens/legal_screen.dart';
import 'package:duka_manager/screens/payment_settings_screen.dart';
import 'package:duka_manager/screens/printer_settings_screen.dart';
import 'package:duka_manager/screens/setup_screen.dart';
import 'package:duka_manager/services/backup_service.dart';
import 'package:duka_manager/services/payhero_service.dart';
import 'package:duka_manager/services/sync_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/shop_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/sales_provider.dart';
import '../providers/report_provider.dart';
import '../widgets/feedback_dialog.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/biometric_service.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameController = TextEditingController();
  String _appVersion = "Loading...";
  String get shopId => Provider.of<ShopProvider>(context, listen: false).shopId;
  
  // 🎨 THEME COLORS
  static const Color primaryOrange = Color(0xFFFF6B00);
  static const Color textDark = Color(0xFF1A1A1A);
  static const Color cardGray = Color(0xFFF5F6F9);
  static const Color dangerRed = Color(0xFFFF453A);

  @override
  void initState() {
    super.initState();
    _initPackageInfo();
    final shop = Provider.of<ShopProvider>(context, listen: false);
    _nameController.text = shop.shopName;
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      // You can show version alone, or version + build number
      _appVersion = "${info.version}+${info.buildNumber}"; 
    });
  }

  Future<void> _paySubscription() async {
  Provider.of<SalesProvider>(context, listen: false);
  final shop = Provider.of<ShopProvider>(context, listen: false);
  final settings = await DatabaseHelper.instance.getSettings();
  
  // Close the requirement dialog first
  Navigator.pop(context);

  // We use a fixed amount of 200 for the monthly subscription
  const double subAmount = 200.0;
  String? mpesaNumber = settings['mpesa_number'];
  if (mpesaNumber == null || mpesaNumber.trim().isEmpty) {
    _showNumberRequiredDialog(); // Create a small dialog to collect the number
    return;
  }

  // Trigger STK Push with SUB prefix
  // ExternalReference will look like: "SUB|SHOP-12345|1735500000"
  String? invoiceId = await PayHeroService().initiateSTKPush(
    phoneNumber: mpesaNumber, 
    amount: subAmount,
    externalReference: shop.generatePayHeroRef("SUB"),
    basicAuth: settings['payhero_auth'], 
    channelId: settings['payhero_channel_id'],
  );

  if (invoiceId != null) {
    // Show the same listening dialog we use for sales
    _showListeningDialog(invoiceId);
  } else {
    FeedbackDialog.show(
      context, 
      title: "Connection Error", 
      message: "Could not initiate payment. Check your API settings.", 
      isSuccess: false
    );
    }
  }


void _showNumberRequiredDialog() {
  final phoneController = TextEditingController();
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text("Missing Phone Number"),
      content: TextField(
        controller: phoneController,
        keyboardType: TextInputType.phone,
        decoration: InputDecoration(hintText: "Enter M-Pesa Number (07xx...)"),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Cancel")),
        ElevatedButton(
          onPressed: () async {
            String num = phoneController.text.trim();
            if (num.length >= 10) {
              // Save it to settings so they don't have to enter it again
              await DatabaseHelper.instance.updateSettings({'mpesa_number': num});
              Navigator.pop(ctx);
              _paySubscription(); // Retry the payment
            }
          },
          child: Text("Save & Pay"),
        )
      ],
    ),
  );
}

  void _showListeningDialog(String invoiceId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('payment_requests').doc(invoiceId).snapshots(),
          builder: (context, snapshot) {
            String status = "PENDING";
            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>;
              status = data['status'] ?? "PENDING";
            }

            // ✅ PAYMENT RECEIVED
            if (status == "PAID") {
              Provider.of<ShopProvider>(context, listen: false).refreshProStatus();
              Future.delayed(Duration(seconds: 2), () {
                Navigator.of(ctx).pop();// Auto-complete sale
              });
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 80),
                    SizedBox(height: 20),
                    Text("Payment Confirmed!", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
              );
            }

            // ❌ PAYMENT FAILED
            if (status == "FAILED") {
              return AlertDialog(
                title: Text("Payment Failed"),
                content: Text("Customer cancelled or insufficient funds."),
                actions: [TextButton(child: Text("Close"), onPressed: () => Navigator.pop(ctx))],
              );
            }

            // ⏳ WAITING STATE
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: primaryOrange),
                  SizedBox(height: 25),
                  Text("Waiting for M-Pesa...", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  SizedBox(height: 10),
                  Text("Ask customer to enter PIN", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                  SizedBox(height: 20),
                  TextButton(child: Text("Cancel", style: TextStyle(color: Colors.red)), onPressed: () => Navigator.pop(ctx))
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSubscriptionRequiredDialog() {
  final wallet = Provider.of<WalletProvider>(context, listen: false);
  final shop = Provider.of<ShopProvider>(context, listen: false);

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text("Upgrade to Pro", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
      content: Text("Cloud Sync and STK Push require a KES 200/mo subscription."),
      actions: [
        // Option 1: Use Wallet Balance
        if (wallet.balance >= 200) 
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              Navigator.pop(ctx);
              final auth = Provider.of<AuthProvider>(context, listen: false);
              bool success = await wallet.paySubscriptionWithWallet(shop.shopId);
              if (success) {
                await shop.loadSubscriptionStatus(auth.user?.uid); // Refresh status
                FeedbackDialog.show(context, title: "Success", message: "Pro activated!", isSuccess: true);
              }
            },
            child: Text("Pay with Balance (KES 200)"),
          ),
        
        // Option 2: Use M-Pesa STK (Existing logic)
        TextButton(
          onPressed: _paySubscription, // Your existing STK Push method
          child: Text("Pay with M-Pesa"),
        ),
      ],
    ),
  );
}



  // 🗑️ LOGIC: Reset App Data
  void _confirmReset() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Factory Reset?", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: dangerRed)),
        content: Text("This will delete ALL products and sales history. This cannot be undone.", style: GoogleFonts.poppins(color: textDark)),
        actions: [
          TextButton(
            child: Text("Cancel", style: GoogleFonts.poppins(color: Colors.grey)),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: dangerRed, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text("Delete Everything", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
            onPressed: () async {
  Navigator.pop(ctx);
  
  // 1. Wipe SQLite Database (Products, Sales, Debts)
  await DatabaseHelper.instance.resetDatabase();
  
  // 2. Wipe Preferences (Shop Name, First Run Flag, Theme)
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear(); // 👈 This resets is_first_run to null/true
  
  // 3. Reload Providers
  if (mounted) {
    Provider.of<InventoryProvider>(context, listen: false).loadProducts();
    Provider.of<SalesProvider>(context, listen: false).clearCart();
    Provider.of<ReportProvider>(context, listen: false).loadDashboardStats();
    
    // 4. Force Restart to Setup Screen
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => SetupScreen()),
      (route) => false, // 👈 Clears the navigation stack
    );
    
    FeedbackDialog.show(context, title: "Reset Complete", message: "System is now empty.", isSuccess: true);
  }
},
          )
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    // Watch ShopProvider to rebuild when settings change
    final shop = Provider.of<ShopProvider>(context);

    return Scaffold(
      backgroundColor: cardGray,
      appBar: AppBar(
        backgroundColor: cardGray,
        elevation: 0,
        title: Text("Settings", style: GoogleFonts.poppins(color: textDark, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: textDark),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SECTION 1: GENERAL
            _buildSectionTitle("General"),
            Container(
              padding: EdgeInsets.all(20),
              decoration: _cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Business Name", style: GoogleFonts.poppins(fontSize: 14, color: textDark)),
                  SizedBox(height: 10),
                  TextField(
                    controller: _nameController,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: textDark),
                    decoration: _inputDecoration("Enter Shop Name"),
                  ),
                  SizedBox(height: 15),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: textDark,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        shop.updateShopName(_nameController.text);
                        FeedbackDialog.show(context, title: "Saved", message: "Business info updated.", isSuccess: true);
                        FocusScope.of(context).unfocus();
                      },
                      child: Text("Save Changes", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 25),

            // SECTION 2: PREFERENCES
            // SECTION 2: PREFERENCES
            _buildSectionTitle("Preferences"),
            Container(
              decoration: _cardDecoration(),
              child: Column(
                children: [
                  // Dark Mode Switch
                  _buildSwitchTile(
                    "Dark Mode", 
                    "Use dark theme", 
                    shop.isDarkMode, 
                    (val) => shop.toggleDarkMode(val)
                  ),
                  Divider(height: 1, color: Colors.grey.shade100),

Card(
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
  child: ListTile(
    leading: const Icon(Icons.fingerprint, color: primaryOrange),
    title: Text("M-Bizna Lock", style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
    subtitle: const Text("Require PIN/Biometrics to view debts, Reports & Settings", style: TextStyle(fontSize: 12)),
    trailing: Switch(
  value: shop.isSecurityEnabled, // ✅ Matches your 'final shop' variable
  activeColor: primaryOrange,
  onChanged: (val) => shop.toggleSecurity(val),
),
  ),
),
                  Divider(height: 1, color: Colors.grey.shade100),
                  
                  // 👤 NEW: ROLE SELECTION (RBAC)
                  _buildSwitchTile(
                    "Attendant Mode ${shop.isProActive ? '' : '(PRO)'}", 
                    shop.isProActive ? "Hide profits and sensitive reports" : "Subscribe to Pro to enable this", 
                    shop.isAttendant, 
                    (val) async {
                      if (!shop.isProActive) {
                        _showSubscriptionRequiredDialog();
                        return;
                      }
                      if (shop.isOwner) {
                        // Switch to Attendant (No PIN needed)
                        await shop.toggleUserRole();
                        FeedbackDialog.show(context, title: "Mode Switched", message: "You are now in Attendant Mode.", isSuccess: true);
                      } else {
                        // Switch to Owner (PIN/Biometric REQUIRED)
                        bool canSwitch = await BiometricService.authenticate();
                        if (canSwitch) {
                          await shop.toggleUserRole();
                          FeedbackDialog.show(context, title: "Success", message: "Welcome back, Owner.", isSuccess: true);
                        } else {
                          FeedbackDialog.show(context, title: "Access Denied", message: "Authenticaton failed.", isSuccess: false);
                        }
                      }
                    }
                  ),
                  Divider(height: 1, color: Colors.grey.shade100),
                  
                  // Sound Effect Switch
                  _buildSwitchTile(
                    "Sound Effects", 
                    "Play sound on scan", 
                    shop.enableSound, 
                    (val) => shop.toggleSound(val)
                  ),
                  Divider(height: 1, color: Colors.grey.shade100),

                  // 🖨️ NEW: PRINTER SETTINGS
                  ListTile(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (c) => PrinterSettingsScreen()));
                    },
                    leading: Container(
                      padding: EdgeInsets.all(8), 
                      decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle), 
                      child: Icon(Icons.print, color: primaryOrange)
                    ),
                    title: Text("Printer Settings", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15, color: textDark)),
                    subtitle: Text("Connect Thermal Printer", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                    trailing: Icon(Icons.chevron_right, color: Colors.grey),
                  ),
                  Divider(height: 1, color: Colors.grey.shade100),
                  // Inside your SettingsScreen build method
ListTile(
  enabled: shop.isProActive, // 🚀 Disable if not currently Pro
  leading: Icon(Icons.refresh, color: shop.isProActive ? primaryOrange : Colors.grey),
  title: Text("Auto-Renew Subscription", 
    style: GoogleFonts.poppins(
      fontWeight: FontWeight.w600,
      color: shop.isProActive ? textDark : Colors.grey // Visual feedback
    )),
  subtitle: Text(shop.isProActive 
    ? "Renew using app balance when expired" 
    : "Subscribe to Pro to enable auto-renew", 
    style: TextStyle(fontSize: 12)),
  trailing: Switch(
    value: shop.autoRenewEnabled,
    activeColor: primaryOrange,
    onChanged: shop.isProActive ? (val) => shop.toggleAutoRenew(val) : null,
  ),
),
Divider(height: 1, color: Colors.grey.shade100),
                  
                  // Currency (Static)
                  ListTile(
                    title: Text("Currency", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15, color: textDark)),
                    subtitle: Text("Kenyan Shilling (KES)", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                    trailing: Icon(Icons.chevron_right, color: Colors.grey),
                  ),
                  Divider(height: 1, color: Colors.grey.shade100),
                  // Inside settings_screen.dart ListView
ListTile(
  leading: Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: primaryOrange.withOpacity(0.1),
      shape: BoxShape.circle,
    ),
    child: const Icon(Icons.account_balance_wallet_outlined, color: primaryOrange),
  ),
  title: Text(
    "M-Pesa & Payments",
    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
  ),
  subtitle: Text(
    "Configure STK Push, Pochi, or PayHero",
    style: GoogleFonts.poppins(fontSize: 12),
  ),
  trailing: const Icon(Icons.chevron_right, size: 20),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PaymentSettingsScreen()),
    );
  },
),
                ],
              ),
            ),

            SizedBox(height: 25),

            // SECTION 3: DATA MANAGEMENT
            _buildSectionTitle("Data Management"),
            Container(
              decoration: _cardDecoration(),
              child: Column(
                children: [
                 ListTile(
              onTap: () async {
  final shop = Provider.of<ShopProvider>(context, listen: false);
  final shopId = shop.shopId;

  // 1. Check if the user has an active Pro Subscription
  if (shop.isProActive) {
    
    // 2. Show Loading UI
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Syncing data to cloud..."),
        duration: Duration(seconds: 2),
      )
    );

    try {
      // 3. Run the Sync Service
      await SyncService().syncAll(shopId);
      
      FeedbackDialog.show(
        context, 
        title: "Backup Complete", 
        message: "Your data is now safely stored in the cloud.", 
        isSuccess: true
      );
    } catch (e) {
      FeedbackDialog.show(
        context, 
        title: "Sync Failed", 
        message: "Please check your internet connection.", 
        isSuccess: false
      );
    }

  } else {
    // 4. If not Pro, show the Subscription Dialog we built earlier
    _showSubscriptionRequiredDialog(); 
  }
},
              leading: Container(
                padding: EdgeInsets.all(8), 
                decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle), 
                child: Icon(Icons.cloud_upload_outlined, color: Colors.blue)
              ),
              title: Text("Cloud Backup", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15, color: textDark)),
              subtitle: Text("Sync Sales, Inventory & Debtors", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
              trailing: Icon(Icons.chevron_right, color: Colors.grey),
            ),
            Divider(height: 1, color: Colors.grey.shade100),

                  // 📂 OPTION 2: Local Backup (Free) - FALLBACK
                  ListTile(
                    onTap: () async {
                      // 👇 Call your existing Service class
                      await BackupService().createAndShareBackup();
                    },
                    leading: Container(
                      padding: EdgeInsets.all(8), 
                      decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle), 
                      child: Icon(Icons.save_alt, color: Colors.green)
                    ),
                    title: Text("Local Backup", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15, color: textDark)),
                    subtitle: Text("Export CSV to phone (Free)", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                    trailing: Icon(Icons.share, size: 20, color: Colors.grey),
                  ),
                  Divider(height: 1, color: Colors.grey.shade100),
                  ListTile(
                    onTap: _confirmReset,
                    leading: Container(padding: EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle), child: Icon(Icons.delete_forever_outlined, color: dangerRed)),
                    title: Text("Reset Everything", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15, color: dangerRed)),
                    subtitle: Text("Delete all products & sales", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                  ),
                ],
              ),
            ),

            SizedBox(height: 25),
            
            _buildSectionTitle("About"),
            Container(
              decoration: _cardDecoration(),
              child: Column(
                children: [
                  ListTile(
                    title: Text("Terms of Service", style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                    trailing: Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => LegalScreen(type: 'Terms'))),
                  ),
                  Divider(height: 1),
                  ListTile(
                    title: Text("Privacy Policy", style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                    trailing: Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => LegalScreen(type: 'Privacy'))),
                  ),
                  Divider(height: 1),
                  ListTile(
  title: Text("Version", style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
  trailing: Text(
    _appVersion, // 👈 Now it shows the real version (e.g., 1.0.2+5)
    style: GoogleFonts.poppins(color: Colors.grey),
  ),
),
                ],
              ),
            ),
            
            SizedBox(height: 50),
            // SECTION 4: SYSTEM INFO
_buildSectionTitle("System Info"),
Container(
  width: double.infinity,
  padding: EdgeInsets.all(20),
  decoration: _cardDecoration(),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text("Unique Shop ID", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              shop.shopId, 
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: primaryOrange, fontSize: 13)
            ),
          ),
          IconButton(
            icon: Icon(Icons.copy, size: 18, color: Colors.grey),
            onPressed: () {
               // Add clipboard logic if needed
               ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("ID Copied")));
            },
          )
        ],
      ),
      Divider(),
      Text("Device Status", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
      Text("Licensed & Verified", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.green, fontSize: 13)),
    ],
  ),
),
            SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  // --- HELPERS ---

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 5),
      child: Text(title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey)),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: Offset(0, 4))],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      filled: true,
      fillColor: cardGray,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      hintText: hint,
      contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 15),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      activeColor: primaryOrange,
      title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15, color: textDark)),
      subtitle: Text(subtitle, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
      value: value,
      onChanged: onChanged,
    );
  }
}