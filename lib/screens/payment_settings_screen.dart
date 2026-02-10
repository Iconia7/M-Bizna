// lib/screens/payment_settings_screen.dart
import 'package:duka_manager/services/payhero_service.dart';
import 'package:duka_manager/widgets/feedback_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For clipboard functionality
import 'package:cloud_functions/cloud_functions.dart';
import 'package:duka_manager/providers/shop_provider.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../db/database_helper.dart';

class PaymentSettingsScreen extends StatefulWidget {
  const PaymentSettingsScreen({super.key});

  @override
  _PaymentSettingsScreenState createState() => _PaymentSettingsScreenState();
}

class _PaymentSettingsScreenState extends State<PaymentSettingsScreen> {
  String _mpesaMode = 'Manual';
  final _numberController = TextEditingController();
  final _authController = TextEditingController();
  final _shortCodeController = TextEditingController();
  final _accountController = TextEditingController(); // For Paybill account
  String _channelType = 'Paybill';
  bool _isTesting = false;
  bool _isActivating = false;
  
  // 🎨 THEME COLORS (Dynamic Getters)
  Color get _primaryOrange => const Color(0xFFFF6B00);
  Color get _surfaceColor => Theme.of(context).colorScheme.surface;
  Color get _containerColor => Theme.of(context).brightness == Brightness.light ? const Color(0xFFF5F6F9) : const Color(0xFF121212);
  Color get _cardColor => Theme.of(context).brightness == Brightness.light ? Colors.white : const Color(0xFF1E1E1E);
  Color get _textColor => Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF1A1A1A);

  static const String callbackUrl = "https://payherocallback-6xi2wmoqdq-uc.a.run.app";

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() async {
    final settings = await DatabaseHelper.instance.getSettings();
    setState(() {
      _mpesaMode = settings['mpesa_mode'] ?? 'Manual';
      _numberController.text = settings['mpesa_number'] ?? '';
      _shortCodeController.text = settings['mpesa_shortcode'] ?? '';
      _accountController.text = settings['mpesa_account'] ?? '';
      _channelType = settings['mpesa_channel_type'] ?? 'Paybill';
      _authController.text = settings['payhero_auth'] ?? '';
    });
  }

  void _showSetupInstructions() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: _surfaceColor,
        title: Text("PayHero Setup Guide", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: _textColor)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _stepText("1. Create account at payhero.co.ke"),
              _stepText("2. Link Till/Paybill in 'Payment Channels'"),
              _stepText("3. Copy 'Channel ID' into this app"),
              _stepText("4. Create & Copy 'API Key' from settings"),
              _stepText("5. Set Callback URL in PayHero to:"),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: _containerColor, borderRadius: BorderRadius.circular(8)),
                child: Text(callbackUrl, style: GoogleFonts.poppins(fontSize: 10, color: _textColor, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(const ClipboardData(text: callbackUrl));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Link Copied!")));
            }, 
            child: const Text("Copy Link")
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Got it")),
        ],
      ),
    );
  }

  Future<void> _activateMerchant() async {
    final shop = Provider.of<ShopProvider>(context, listen: false);
    String shortCode = _shortCodeController.text.trim();
    String account = _accountController.text.trim();

    if (shortCode.isEmpty) {
      FeedbackDialog.show(context, title: "Required", message: "Enter your Till or Paybill number.", isSuccess: false);
      return;
    }

    setState(() => _isActivating = true);

    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('activateMerchantChannel');
      
      final result = await callable.call({
        'shop_id': shop.shopId,
        'shop_name': shop.shopName,
        'type': _channelType == 'Till' ? 'till' : 'paybill',
        'short_code': shortCode,
        'till_number': _channelType == 'Till' ? shortCode : null,
      });

      if (result.data['success'] == true) {
        // Success! Cloud function should have updated the shop doc with credentials
        // We trigger a reload of subscription status to fetch them
        await shop.loadSubscriptionStatus(null); 
        
        if (!mounted) return;

        setState(() {
          _authController.text = shop.payheroChannelId; // If we store it there
          // Note: In a real flow, the app might fetch the key from Firestore 
          // but we'll assume the Cloud Function sets it in the shop doc.
        });

        FeedbackDialog.show(context, title: "Linked!", message: "Your business is now connected to M-Pesa.", isSuccess: true);
      } else {
        FeedbackDialog.show(context, title: "Failed", message: result.data['message'] ?? "Could not activate channel.", isSuccess: false);
      }
    } catch (e) {
      FeedbackDialog.show(context, title: "Error", message: e.toString(), isSuccess: false);
    } finally {
      setState(() => _isActivating = false);
    }
  }

  Future<void> _testConnection() async {
    if (_authController.text.isEmpty || _shortCodeController.text.isEmpty) {
      FeedbackDialog.show(context, title: "Missing Info", message: "Link your business or enter credentials first.", isSuccess: false);
      return;
    }

    setState(() => _isTesting = true);

    final success = await PayHeroService().initiateSTKPush(
      phoneNumber: "254700000000", 
      amount: 1.0, 
      externalReference: "TEST|${DateTime.now().millisecondsSinceEpoch}",
      basicAuth: _authController.text,
      channelId: _shortCodeController.text, // Assuming shortcode is used as channelId for manual entry
    );

    setState(() => _isTesting = false);

    if (!mounted) return;

    if (success != null) {
      FeedbackDialog.show(context, title: "Connected!", message: "PayHero credentials are valid.", isSuccess: true);
    } else {
      FeedbackDialog.show(context, title: "Failed", message: "Check your credentials.", isSuccess: false);
    }
  }

  void _saveSettings() async {
    await DatabaseHelper.instance.updateSettings({
      'mpesa_mode': _mpesaMode,
      'mpesa_number': _numberController.text,
      'mpesa_shortcode': _shortCodeController.text,
      'mpesa_account': _accountController.text,
      'mpesa_channel_type': _channelType,
      'payhero_auth': _authController.text,
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Payment Settings Saved!")));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _containerColor,
      appBar: AppBar(
        title: Text("Payment Settings", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: _textColor)),
        backgroundColor: _containerColor,
        elevation: 0,
        iconTheme: IconThemeData(color: _textColor),
        actions: [
          IconButton(icon: Icon(Icons.help_outline, color: _textColor), onPressed: _showSetupInstructions),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Select M-Pesa Mode", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16, color: _textColor)),
            const SizedBox(height: 10),
            _buildModeCard(
              title: "Manual (Pochi/Personal)",
              subtitle: "Free - Merchant confirms SMS manually",
              value: 'Manual',
            ),
            _buildModeCard(
              title: "Automated (STK Push)",
              subtitle: "Pro - Auto-verify with PayHero API",
              value: 'Automated',
            ),
            const SizedBox(height: 20),
            if (_mpesaMode == 'Manual') 
              _buildModernInput(_numberController, "Your M-Pesa Number", Icons.phone_android)
            else ...[
              _buildChannelTypeToggle(),
              const SizedBox(height: 15),
              if (_channelType == 'Paybill') ...[
                _buildModernInput(_shortCodeController, "Paybill Number", Icons.numbers),
                const SizedBox(height: 15),
                _buildModernInput(_accountController, "Account (Default: SHOP)", Icons.badge),
              ] else ...[
                _buildModernInput(_shortCodeController, "Till Number", Icons.store),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isActivating ? null : _activateMerchant,
                  icon: _isActivating 
                    ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.auto_awesome, color: Colors.white),
                  label: Text(_isActivating ? "Activating..." : "Link My Business Automatically", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryOrange,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: TextButton.icon(
                  onPressed: _isTesting ? null : _testConnection, 
                  icon: _isTesting 
                    ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.flash_on, color: Color(0xFFFF6B00)), 
                  label: Text(_isTesting ? "Testing..." : "Verify Current Connection", style: const TextStyle(color: Color(0xFFFF6B00)))
                ),
              ),
            ],
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _saveSettings, 
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).brightness == Brightness.light ? const Color(0xFF1A1A1A) : const Color(0xFF333333),
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
              ),
              child: Text("Save Configuration", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeCard({required String title, required String subtitle, required String value}) {
    return Card(
      elevation: 0,
      color: _cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      margin: const EdgeInsets.only(bottom: 10),
      child: RadioListTile(
        title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14, color: _textColor)),
        subtitle: Text(subtitle, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
        value: value, 
        groupValue: _mpesaMode, 
        activeColor: _primaryOrange,
        onChanged: (val) => setState(() => _mpesaMode = val as String),
      ),
    );
  }

  Widget _buildChannelTypeToggle() {
    return Row(
      children: [
        Expanded(child: _buildTypeButton("Paybill", _channelType == 'Paybill', () => setState(() => _channelType = 'Paybill'))),
        const SizedBox(width: 12),
        Expanded(child: _buildTypeButton("Till Number", _channelType == 'Till', () => setState(() => _channelType = 'Till'))),
      ],
    );
  }

  Widget _buildTypeButton(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? _primaryOrange : _cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? _primaryOrange : Colors.grey.withOpacity(0.3)),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepText(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4), 
    child: Text(text, style: GoogleFonts.poppins(fontSize: 13, color: _textColor.withOpacity(0.8)))
  );

  Widget _buildModernInput(TextEditingController ctrl, String label, IconData icon) {
    return Container(
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(15)),
      child: TextField(
        controller: ctrl,
        style: GoogleFonts.poppins(color: _textColor),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(color: Colors.grey),
          prefixIcon: Icon(icon, color: _primaryOrange),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          filled: true,
          fillColor: _cardColor,
        ),
      ),
    );
  }
}