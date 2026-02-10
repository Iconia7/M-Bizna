import 'package:duka_manager/providers/auth_provider.dart';
import 'package:duka_manager/widgets/feedback_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../providers/shop_provider.dart';
import '../db/database_helper.dart'; 
import 'home_screen.dart';

class SetupScreen extends StatefulWidget {
  @override
  _SetupScreenState createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  // Controllers
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _numberController = TextEditingController();
  final _shortCodeController = TextEditingController(); // 👈 Renamed
  final _tillNumberController = TextEditingController(); // 👈 Renamed
  
  // OTP Focused Controllers & Nodes
  final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpNodes = List.generate(6, (_) => FocusNode());

  // State Variables
  bool _isLoading = false;
  bool _isOTPSent = false;
  bool _isPaymentSetup = false; 
  bool _isAuthComplete = false;
  String _mpesaMode = 'Manual';
  double _setupProgress = 0.0;
  String _statusMessage = "Starting setup...";
  String _channelType = 'Paybill'; // 👈 NEW: 'Paybill' or 'Till'

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _numberController.dispose();
    _shortCodeController.dispose();
    _tillNumberController.dispose();
    for (var c in _otpControllers) {
      c.dispose();
    }
    for (var n in _otpNodes) {
      n.dispose();
    }
    super.dispose();
  }

  // 🎨 THEME COLORS (Now using dynamic getters)
  Color get _primaryOrange => const Color(0xFFFF6B00);
  Color get _surfaceColor => Theme.of(context).colorScheme.surface;
  Color get _containerColor => Theme.of(context).brightness == Brightness.light ? const Color(0xFFF5F6F9) : Colors.white.withOpacity(0.05);
  Color get _cardColor => Theme.of(context).brightness == Brightness.light ? Colors.white : const Color(0xFF1E1E1E);
  Color get _textColor => Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF1A1A1A);

  // Constants
  static const String callbackUrl = "https://payherocallback-6xi2wmoqdq-uc.a.run.app";

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
              _stepText("1. Enter your M-Pesa Business details here"),
              _stepText("2. M-Bizna automatically registers your store"),
              _stepText("3. Start receiving STK prompts immediately"),
              _stepText("4. Note: Transaction fees apply for automated STK"),
              const SizedBox(height: 10),
              _stepText("Developer Tip: Set your Callback URL in PayHero to:"),
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

  Widget _stepText(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4), 
    child: Text(text, style: GoogleFonts.poppins(fontSize: 13, color: _textColor.withOpacity(0.8)))
  );

  void _verifyPhone() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    String phone = _phoneController.text.trim();
    if (!phone.startsWith("+")) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Include country code (e.g. +254)")));
      return;
    }

    setState(() => _isLoading = true);
    await auth.verifyPhoneNumber(
      phone,
      onCodeSent: (_) => setState(() {
        _isLoading = false;
        _isOTPSent = true;
      }),
      onError: (err) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      },
    );
  }

  void _verifyOTP() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final shopProvider = Provider.of<ShopProvider>(context, listen: false);
    setState(() => _isLoading = true);
    
    String otp = _otpControllers.map((c) => c.text).join();
    bool success = await auth.signInWithOTP(otp);
    
    if (!mounted) return;

    if (success) {
      String uid = auth.user!.uid;
      
      setState(() {
        _statusMessage = "Identifying your account...";
        _setupProgress = 0.5;
      });

      // 🕵️ Check if this UID already has a shop
      String? existingShopId = await shopProvider.findShopByUid(uid);
      
      if (!mounted) return;

      if (existingShopId != null) {
        // Recovery path
        final prefs = await SharedPreferences.getInstance();

        if (!mounted) return;

        await prefs.setBool('is_first_run', false);
        
        setState(() {
          _statusMessage = "Welcome back! Synchronizing shop...";
          _setupProgress = 1.0;
        });

        await Future.delayed(const Duration(milliseconds: 800));
        
        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => HomeScreen()));
        }
      } else {
        // New user path
        setState(() {
          _isLoading = false;
          _isAuthComplete = true;
        });
      }
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Invalid OTP")));
    }
  }

  void _finishSetup() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final shopProvider = Provider.of<ShopProvider>(context, listen: false);
    
    String shopName = _nameController.text.trim();
    String mpesaNum = _numberController.text.trim();
    String shortCode = _shortCodeController.text.trim();
    String tillNumber = _tillNumberController.text.trim();

    if (shopName.isEmpty) return;

    setState(() {
      _isLoading = true;
      _setupProgress = 0.1;
      _statusMessage = "Creating your business profile...";
    });

    try {
      await shopProvider.updateShopName(shopName);
      String shopId = shopProvider.shopId;
      String uid = auth.user!.uid;

      setState(() {
        _setupProgress = 0.4;
        _statusMessage = "Registering with M-Pesa network...";
      });

      // 🚀 AUTOMATED ACTIVATION VIA CLOUD FUNCTIONS
      if (_mpesaMode == 'Automated') {
        final functions = FirebaseFunctions.instance;
        final callable = functions.httpsCallable('activateMerchantChannel');
        
        final result = await callable.call({
          'shop_id': shopId,
          'shop_name': shopName,
          'type': _channelType == 'Till' ? 'till' : 'paybill', // 👈 Map to PayHero API values (lowercase)
          'short_code': shortCode,
          'till_number': _channelType == 'Till' ? shortCode : null, // PayHero usually needs till # in both for Tills
        });

        if (result.data['success'] != true) {
          throw Exception(result.data['message'] ?? "Activation failed.");
        }
      }

      if (!mounted) return;

      setState(() {
        _setupProgress = 0.7;
        _statusMessage = "Finalizing secure link...";
      });

      // Save Local Settings
      await DatabaseHelper.instance.updateSettings({
        'mpesa_mode': _mpesaMode,
        'mpesa_number': mpesaNum,
        'mpesa_channel_type': _channelType,
        'mpesa_shortcode': shortCode,
        'mpesa_account': tillNumber,
      });

      setState(() {
        _setupProgress = 0.8;
        _statusMessage = "Linking account to secure cloud...";
      });

      // Cloud Initialization with UID linking
      await FirebaseFirestore.instance.collection('shops').doc(shopId).set({
        'shop_name': shopName,
        'owner_uid': uid, // 👈 Link to account
        'wallet_balance': 0.0,
        'mpesa_config': _mpesaMode,
        'mpesa_channel_type': _channelType,
        'mpesa_shortcode': shortCode,
        'mpesa_account': tillNumber,
        'auto_renew': false,
        'is_pro': false,
        'createdAt': FieldValue.serverTimestamp(),
        'is_active': true,
      }, SetOptions(merge: true));

      if (!mounted) return;

      setState(() {
        _setupProgress = 1.0;
        _statusMessage = "Finalizing settings...";
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_first_run', false);
      
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => HomeScreen()));
      }
    } catch (e) {
      debugPrint("❌ SETUP ERROR: $e");
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Setup failed: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _containerColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _containerColor,
              _surfaceColor
            ],
            stops: const [0.0, 0.4],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 48),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.1),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey<String>(
                      _isAuthComplete 
                          ? (_isPaymentSetup ? 'payment' : 'shop') 
                          : (_isOTPSent ? 'otp' : 'auth')
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: _cardColor,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 40,
                            offset: const Offset(0, 20),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!_isAuthComplete) _buildAuthView()
                          else if (!_isPaymentSetup) _buildShopNameView() 
                          else _buildPaymentSetupView(),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                if (!_isLoading) _buildFooterText(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Hero(
          tag: 'logo',
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _cardColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _primaryOrange.withOpacity(0.12),
                  blurRadius: 32,
                  offset: const Offset(0, 16),
                )
              ],
            ),
            child: Icon(Icons.storefront_rounded, size: 56, color: _primaryOrange),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          "M-Bizna",
          style: GoogleFonts.outfit(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            color: _textColor,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isAuthComplete ? "Business Profile" : "Secure Authentication",
          style: GoogleFonts.poppins(
            color: _primaryOrange,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            _isAuthComplete 
                ? "Let's personalize your store experience." 
                : "Enter your mobile number to get started with M-Bizna Cloud.",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.grey.shade500,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAuthView() {
    return Column(
      children: [
        if (!_isOTPSent) ...[
          _buildInputField(_phoneController, "Phone Number", "+254...", Icons.phone),
          const SizedBox(height: 20),
          if (_isLoading) _buildProgressUI()
          else _buildWideButton("SEND VERIFICATION CODE", _verifyPhone),
        ] else ...[
          _buildModernOTPInput(),
          const SizedBox(height: 30),
          if (_isLoading) _buildProgressUI()
          else _buildWideButton("VERIFY & RESTORE", _verifyOTP),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => setState(() => _isOTPSent = false), 
            child: Text("Change phone number", style: TextStyle(color: Colors.grey.shade600, fontSize: 13))
          )
        ]
      ],
    );
  }

  Widget _buildShopNameView() {
    return Column(
      children: [
        _buildInputField(_nameController, "Business Name", "e.g. Mama Njuguna's Grocery", Icons.edit_note),
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
            Text("Payment Configuration", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
            if (_mpesaMode == 'Automated')
              IconButton(icon: Icon(Icons.help_outline, color: _primaryOrange), onPressed: _showSetupInstructions),
          ],
        ),
        const SizedBox(height: 10),
        _buildMpesaToggle(),
        const SizedBox(height: 20),
        if (_mpesaMode == 'Manual')
          _buildInputField(_numberController, "Your M-Pesa Number", "07XX... (For Display Only)", Icons.phone_android)
        else ...[
          _buildChannelTypeToggle(),
          const SizedBox(height: 20),
          if (_channelType == 'Paybill') ...[
            _buildInputField(_shortCodeController, "Paybill Number", "e.g. 400222", Icons.numbers),
            const SizedBox(height: 15),
            _buildInputField(_tillNumberController, "Account Number (e.g. SHOP)", "Optional", Icons.badge),
          ] else ...[
            _buildInputField(_shortCodeController, "Till Number", "e.g. 123456", Icons.store),
          ],
        ],
        const SizedBox(height: 40),
        _isLoading ? _buildProgressUI() : Column(
          children: [
            _buildWideButton("FINISH SETUP", _finishSetup),
            TextButton(onPressed: () => setState(() => _isPaymentSetup = false), child: const Text("Back", style: TextStyle(color: Colors.grey))),
          ],
        ),
      ],
    );
  }

  Widget _buildMpesaToggle() {
    return Column(
      children: [
        _buildRadioCard(
          "Manual (Pochi/Personal)", 
          "Free - Confirm payments via SMS", 
          'Manual', 
          (val) => setState(() => _mpesaMode = val)
        ),
        _buildRadioCard(
          "Automated (STK Push)", 
          "Pro - Auto-verify. Fees apply per sale.", 
          'Automated', 
          (val) => setState(() => _mpesaMode = val),
          onInfoTap: _showPricingSheet,
        ),
      ],
    );
  }

  Widget _buildChannelTypeToggle() {
    return Row(
      children: [
        Expanded(child: _buildTypeButton("Paybill", _channelType == 'Paybill', () => setState(() => _channelType = 'Paybill'))),
        const SizedBox(width: 12),
        Expanded(child: _buildTypeButton("Buy Goods (Till)", _channelType == 'Till', () => setState(() => _channelType = 'Till'))),
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
          color: isSelected ? _primaryOrange : _surfaceColor,
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

  Widget _buildRadioCard(String title, String subtitle, String value, Function(String) onChanged, {VoidCallback? onInfoTap}) {
    return Card(
      elevation: 0,
      color: _containerColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      margin: const EdgeInsets.only(bottom: 12),
      child: RadioListTile(
        title: Row(
          children: [
            Expanded(child: Text(title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: _textColor))),
            if (onInfoTap != null)
              IconButton(
                icon: Icon(Icons.info_outline, size: 20, color: _primaryOrange),
                onPressed: onInfoTap,
              ),
          ],
        ),
        subtitle: Text(subtitle, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade600)),
        value: value,
        groupValue: _mpesaMode,
        activeColor: _primaryOrange,
        onChanged: (val) => onChanged(val as String),
      ),
    );
  }

  void _showPricingSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Automated STK Pricing", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w800, color: _textColor)),
            const SizedBox(height: 8),
            Text("Fees are deducted from your M-Bizna wallet per successful sale.", style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade600)),
            const SizedBox(height: 24),
            _buildPriceRow("Sale Amount", "Total Fee", isHeader: true),
            const Divider(),
            Expanded(
              child: ListView(
                children: [
                  _buildPriceRow("KES 1 - 49", "KES 2"),
                  _buildPriceRow("KES 50 - 499", "KES 8"),
                  _buildPriceRow("KES 500 - 999", "KES 12"),
                  _buildPriceRow("KES 1k - 1.5k", "KES 17"),
                  _buildPriceRow("KES 1.5k - 2.5k", "KES 22"),
                  _buildPriceRow("KES 2.5k - 5k", "KES 27 - 32"),
                  _buildPriceRow("Over 5k", "KES 42+"),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text("*Includes PayHero cost + KES 2 service fee", style: GoogleFonts.poppins(fontSize: 11, fontStyle: FontStyle.italic)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, String price, {bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 14, fontWeight: isHeader ? FontWeight.bold : FontWeight.w500)),
          Text(price, style: GoogleFonts.poppins(fontSize: 14, fontWeight: isHeader ? FontWeight.bold : FontWeight.w800, color: isHeader ? _textColor : _primaryOrange)),
        ],
      ),
    );
  }

  Widget _buildInputField(TextEditingController ctrl, String label, String hint, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _textColor.withOpacity(0.6),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: _containerColor,
            borderRadius: BorderRadius.circular(18),
          ),
          child: TextField(
            controller: ctrl,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15, color: _textColor),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400, fontSize: 14),
              prefixIcon: Icon(icon, color: _primaryOrange, size: 22),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWideButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).brightness == Brightness.light ? const Color(0xFF1A1A1A) : _primaryOrange, 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))
        ),
        onPressed: onPressed,
        child: Text(text, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  Widget _buildProgressUI() {
    return Column(
      children: [
        Text("${(_setupProgress * 100).toInt()}%", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: _primaryOrange, fontSize: 18)),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(value: _setupProgress, backgroundColor: Colors.grey.shade300, valueColor: AlwaysStoppedAnimation<Color>(_primaryOrange), minHeight: 6),
        ),
        const SizedBox(height: 10),
        Text(_statusMessage, style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 12)),
      ],
    );
  }

  Widget _buildModernOTPInput() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, (index) {
        return Container(
          width: 45,
          height: 55,
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4)
              )
            ],
            border: Border.all(
              color: _otpNodes[index].hasFocus ? _primaryOrange : Colors.transparent,
              width: 2
            ),
          ),
          child: TextField(
            controller: _otpControllers[index],
            focusNode: _otpNodes[index],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: _textColor),
            decoration: const InputDecoration(
              counterText: "",
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero
            ),
            onChanged: (value) {
              if (value.isNotEmpty && index < 5) {
                _otpNodes[index + 1].requestFocus();
              } else if (value.isEmpty && index > 0) {
                _otpNodes[index - 1].requestFocus();
              }
              // If last box is filled, try to verify automatically
              if (index == 5 && value.isNotEmpty) {
                _verifyOTP();
              }
              setState(() {}); // Rebuild for border color
            },
          ),
        );
      }),
    );
  }

  Widget _buildFooterText() {
    return Text(
      "Securely powered by M-Bizna Cloud",
      textAlign: TextAlign.center,
      style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey),
    );
  }
}