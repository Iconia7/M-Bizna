// lib/screens/payment_settings_screen.dart
import 'package:duka_manager/services/payhero_service.dart';
import 'package:duka_manager/widgets/feedback_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For clipboard functionality
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
  final _channelController = TextEditingController();
  final _authController = TextEditingController();
  bool _isTesting = false;
  
  static const Color primaryOrange = Color(0xFFFF6B00);
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
      _channelController.text = settings['payhero_channel_id'] ?? '';
      _authController.text = settings['payhero_auth'] ?? '';
    });
  }

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
              _stepText("1. Create account at payhero.co.ke"),
              _stepText("2. Link Till/Paybill in 'Payment Channels'"),
              _stepText("3. Copy 'Channel ID' into this app"),
              _stepText("4. Create & Copy 'API Key' from settings"),
              _stepText("5. Set Callback URL in PayHero to:"),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                child: Text(callbackUrl, style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
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

  Future<void> _testConnection() async {
    if (_authController.text.isEmpty || _channelController.text.isEmpty) {
      FeedbackDialog.show(context, title: "Missing Info", message: "Enter Channel ID and Key first.", isSuccess: false);
      return;
    }

    setState(() => _isTesting = true);

    final success = await PayHeroService().initiateSTKPush(
      phoneNumber: "254700000000", 
      amount: 1.0, 
      externalReference: "TEST|${DateTime.now().millisecondsSinceEpoch}",
      basicAuth: _authController.text,
      channelId: _channelController.text,
    );

    setState(() => _isTesting = false);

    if (success != null) {
      FeedbackDialog.show(context, title: "Connected!", message: "PayHero credentials are valid.", isSuccess: true);
    } else {
      FeedbackDialog.show(context, title: "Failed", message: "Check your Channel ID or Auth Key.", isSuccess: false);
    }
  }

  void _saveSettings() async {
    await DatabaseHelper.instance.updateSettings({
      'mpesa_mode': _mpesaMode,
      'mpesa_number': _numberController.text,
      'payhero_channel_id': _channelController.text,
      'payhero_auth': _authController.text,
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Payment Settings Saved!")));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: Text("Payment Settings", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.help_outline), onPressed: _showSetupInstructions),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Select M-Pesa Mode", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
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
              _buildModernInput(_channelController, "PayHero Channel ID", Icons.numbers),
              const SizedBox(height: 15),
              _buildModernInput(_authController, "PayHero API Auth Key", Icons.key),
              const SizedBox(height: 10),
              Center(
                child: TextButton.icon(
                  onPressed: _isTesting ? null : _testConnection, 
                  icon: _isTesting 
                    ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.flash_on, color: primaryOrange), 
                  label: Text(_isTesting ? "Testing..." : "Test API Connection", style: const TextStyle(color: primaryOrange))
                ),
              ),
            ],
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _saveSettings, 
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A1A1A),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      margin: const EdgeInsets.only(bottom: 10),
      child: RadioListTile(
        title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
        value: value, 
        groupValue: _mpesaMode, 
        activeColor: primaryOrange,
        onChanged: (val) => setState(() => _mpesaMode = val as String),
      ),
    );
  }

  Widget _stepText(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4), 
    child: Text(text, style: GoogleFonts.poppins(fontSize: 13))
  );

  Widget _buildModernInput(TextEditingController ctrl, String label, IconData icon) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
      child: TextField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: primaryOrange),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }
}