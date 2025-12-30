import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/shop_provider.dart';
import '../db/database_helper.dart'; 
import 'home_screen.dart';

class SetupScreen extends StatefulWidget {
  @override
  _SetupScreenState createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  // Controllers
  final _nameController = TextEditingController();
  final _numberController = TextEditingController();
  final _channelController = TextEditingController();
  final _authController = TextEditingController();

  // State Variables
  bool _isLoading = false;
  bool _isPaymentSetup = false; 
  String _mpesaMode = 'Manual';
  double _setupProgress = 0.0;
  String _statusMessage = "Starting setup...";

  // 🎨 THEME COLORS
  static const Color primaryOrange = Color(0xFFFF6B00);
  static const Color textDark = Color(0xFF1A1A1A);
  static const Color cardGray = Color(0xFFF5F6F9);

  // 🚀 NEW: Instruction Dialog for PayHero
  void _showSetupInstructions() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("PayHero Setup Guide", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _stepText("1. Create an account at payhero.co.ke"),
              _stepText("2. Go to 'Settings' > 'Payment Channels' and add your Till/Paybill"),
              _stepText("3. Copy the 'Channel ID' into this app"),
              _stepText("4. Go to 'Settings' > 'API Keys' > CREATE API KEY and copy the 'Auth Token'"),
              _stepText("5. Set your Callback URL to:"),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                child: const Text(
                  "https://payherocallback-6xi2wmoqdq-uc.a.run.app",
                  style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.blueGrey),
                ),
              ),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Got it"))],
      ),
    );
  }

  Widget _stepText(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6), 
    child: Text(text, style: GoogleFonts.poppins(fontSize: 13, color: Colors.black87))
  );

void _finishSetup() async {
    String shopName = _nameController.text.trim();
    String mpesaNum = _numberController.text.trim();
    String channelId = _channelController.text.trim();
    String authKey = _authController.text.trim();

    // 🛑 VALIDATION GATE
    if (shopName.isEmpty) return;

    if (_mpesaMode == 'Manual' && mpesaNum.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your M-Pesa number for Manual mode.")),
      );
      return;
    }

    if (_mpesaMode == 'Automated') {
      if (channelId.isEmpty || authKey.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Automated mode requires Channel ID and API Key.")),
        );
        return;
      }
    }

    // --- Start Setup Process ---
    setState(() {
      _isLoading = true;
      _setupProgress = 0.1;
      _statusMessage = "Creating your business profile...";
    });

    try {
      final shopProvider = Provider.of<ShopProvider>(context, listen: false);
      
      await Future.delayed(const Duration(milliseconds: 500));
      await shopProvider.updateShopName(shopName);
      String shopId = shopProvider.shopId;
      
      setState(() {
        _setupProgress = 0.3;
        _statusMessage = "Configuring payment methods...";
      });

      // Step 2: Save Hybrid Payment Settings to SQLite
      await DatabaseHelper.instance.updateSettings({
        'mpesa_mode': _mpesaMode,
        'mpesa_number': mpesaNum,
        'payhero_channel_id': channelId,
        'payhero_auth': authKey,
      });

      setState(() {
        _setupProgress = 0.6;
        _statusMessage = "Securing cloud storage for $shopName...";
      });

      // Step 3: Cloud Initialization
      await FirebaseFirestore.instance.collection('shops').doc(shopId).set({
        'shop_name': shopName,
        'wallet_balance': 0.0,
        'mpesa_config': _mpesaMode,
        'auto_renew': false, // 🚀 Default auto-renew to off
        'is_pro': false,     // 🚀 Default Pro to off
        'created_at': FieldValue.serverTimestamp(),
        'is_active': true,
      }, SetOptions(merge: true));

      setState(() {
        _setupProgress = 0.9;
        _statusMessage = "Finalizing your dashboard...";
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_first_run', false);
      
      setState(() {
        _setupProgress = 1.0;
        _statusMessage = "Ready to sell!";
      });

      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomeScreen()),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Setup failed. Check your internet connection.")),
      );
    }
  }

  void _showReceiptPreview(BuildContext context) {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a shop name first!")),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  Text(
                    _nameController.text.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.courierPrime(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.black,
                    ),
                  ),
                  const Text("OFFICIAL RECEIPT", style: TextStyle(fontSize: 10, color: Colors.black)),
                  const Divider(color: Colors.black),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("1x Sample Item", style: GoogleFonts.courierPrime(color: Colors.black, fontSize: 12)),
                      Text("500", style: GoogleFonts.courierPrime(color: Colors.black, fontSize: 12)),
                    ],
                  ),
                  const Divider(color: Colors.black),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("TOTAL", style: GoogleFonts.courierPrime(fontWeight: FontWeight.bold, color: Colors.black)),
                      Text("KES 500.00", style: GoogleFonts.courierPrime(fontWeight: FontWeight.bold, color: Colors.black)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text("Thank you for shopping!", style: TextStyle(fontSize: 9, color: Colors.black)),
                ],
              ),
            ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Looks Good!"))
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cardGray,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 40.0),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 40),
              if (!_isPaymentSetup) _buildShopNameView() else _buildPaymentSetupView(),
              const SizedBox(height: 20),
              if (!_isLoading) _buildFooterText(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))
          ]),
          child: const Icon(Icons.storefront_rounded, size: 60, color: primaryOrange),
        ),
        const SizedBox(height: 20),
        Text("M-Bizna", style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: textDark)),
        Text(
          _isPaymentSetup ? "Configure your payments" : "Let's get your shop ready.",
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 15),
        ),
      ],
    );
  }

  Widget _buildShopNameView() {
    return Column(
      children: [
        _buildInputField(_nameController, "Business Name", "e.g. Mama Njuguna's Grocery", Icons.edit_note),
        const SizedBox(height: 30),
        TextButton.icon(
          onPressed: () => _showReceiptPreview(context),
          icon: const Icon(Icons.receipt_long, color: primaryOrange, size: 20),
          label: Text("Preview Receipt", style: GoogleFonts.poppins(color: primaryOrange, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 40),
        _buildWideButton("NEXT STEP", () {
          if (_nameController.text.trim().isNotEmpty) setState(() => _isPaymentSetup = true);
        }),
      ],
    );
  }

  Widget _buildPaymentSetupView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("How will customers pay?", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
            if (_mpesaMode == 'Automated')
              IconButton(
                icon: const Icon(Icons.help_outline, color: primaryOrange),
                onPressed: _showSetupInstructions,
              ),
          ],
        ),
        const SizedBox(height: 10),
        _buildMpesaToggle(),
        const SizedBox(height: 20),
        if (_mpesaMode == 'Manual')
          _buildInputField(_numberController, "Your M-Pesa Number", "07XX XXX XXX", Icons.phone_android)
        else ...[
          _buildInputField(_channelController, "PayHero Channel ID", "1234", Icons.numbers),
          const SizedBox(height: 15),
          _buildInputField(_authController, "API Auth Token", "Basic Auth Key", Icons.key),
        ],
        const SizedBox(height: 40),
        _isLoading ? _buildProgressUI() : Column(
          children: [
            _buildWideButton("FINISH SETUP", _finishSetup),
            TextButton(onPressed: () => setState(() => _isPaymentSetup = false), child: const Text("Back", style: TextStyle(color: Colors.grey))),
            TextButton(onPressed: _finishSetup, child: const Text("Skip for now", style: TextStyle(color: primaryOrange, fontSize: 12))),
          ],
        ),
      ],
    );
  }

  Widget _buildMpesaToggle() {
    return Column(
      children: [
        RadioListTile(
          title: const Text("Manual (Pochi/Personal)", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: const Text("Confirm payments via SMS", style: TextStyle(fontSize: 11)),
          value: 'Manual',
          groupValue: _mpesaMode,
          activeColor: primaryOrange,
          onChanged: (val) => setState(() => _mpesaMode = val as String),
        ),
        RadioListTile(
          title: const Text("Automated (STK Push)", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: const Text("Professional API verification", style: TextStyle(fontSize: 11)),
          value: 'Automated',
          groupValue: _mpesaMode,
          activeColor: primaryOrange,
          onChanged: (val) => setState(() => _mpesaMode = val as String),
        ),
      ],
    );
  }

  Widget _buildInputField(TextEditingController ctrl, String label, String hint, IconData icon) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 5))
      ]),
      child: TextField(
        controller: ctrl,
        style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: primaryOrange),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildWideButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(backgroundColor: textDark, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
        child: Text(text, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  Widget _buildProgressUI() {
    return Column(
      children: [
        Text("${(_setupProgress * 100).toInt()}%", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: primaryOrange, fontSize: 20)),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(value: _setupProgress, backgroundColor: Colors.grey.shade300, valueColor: const AlwaysStoppedAnimation<Color>(primaryOrange), minHeight: 8),
        ),
        const SizedBox(height: 10),
        Text(_statusMessage, style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 13)),
      ],
    );
  }

  Widget _buildFooterText() {
    return Text(
      "By tapping 'Finish Setup' you agree to our\nTerms and Privacy Policy",
      textAlign: TextAlign.center,
      style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey),
    );
  }
}