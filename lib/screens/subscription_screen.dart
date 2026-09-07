import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:duka_manager/db/database_helper.dart';
import 'package:duka_manager/providers/auth_provider.dart';
import 'package:duka_manager/providers/shop_provider.dart';
import 'package:duka_manager/services/payhero_service.dart';
import 'package:duka_manager/widgets/feedback_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class SubscriptionPlan {
  final String id;
  final String title;
  final String duration;
  final double amount;
  final String? badge;
  final String savings;

  const SubscriptionPlan({
    required this.id,
    required this.title,
    required this.duration,
    required this.amount,
    this.badge,
    required this.savings,
  });
}

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final TextEditingController _phoneController = TextEditingController();
  
  final List<SubscriptionPlan> _plans = const [
    SubscriptionPlan(
      id: '1_month',
      title: "1 Month Pro",
      duration: "30 Days",
      amount: 200.0,
      savings: "Standard Monthly Plan",
    ),
    SubscriptionPlan(
      id: '3_months',
      title: "3 Months Pro",
      duration: "90 Days",
      amount: 550.0,
      badge: "POPULAR",
      savings: "Save KES 50",
    ),
    SubscriptionPlan(
      id: '1_year',
      title: "1 Year Pro",
      duration: "365 Days",
      amount: 2000.0,
      badge: "BEST VALUE",
      savings: "2 Months Free (Save KES 400)",
    ),
  ];

  late SubscriptionPlan _selectedPlan;
  bool _isLoading = false;

  Color get _primaryOrange => const Color(0xFFFF6B00);
  Color get _surfaceColor => Theme.of(context).colorScheme.surface;
  Color get _containerColor => Theme.of(context).brightness == Brightness.light ? const Color(0xFFF5F6F9) : const Color(0xFF121212);
  Color get _cardColor => Theme.of(context).brightness == Brightness.light ? Colors.white : const Color(0xFF1E1E1E);
  Color get _textColor => Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF1A1A1A);

  @override
  void initState() {
    super.initState();
    _selectedPlan = _plans[0];
    _loadSavedPhone();
  }

  void _loadSavedPhone() async {
    final settings = await DatabaseHelper.instance.getSettings();
    if (settings['mpesa_number'] != null && settings['mpesa_number'].toString().isNotEmpty) {
      setState(() {
        _phoneController.text = settings['mpesa_number'].toString();
      });
    }
  }

  Future<void> _initiateSubscriptionPayment() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone.length < 10) {
      FeedbackDialog.show(context, title: "Invalid Phone", message: "Please enter a valid M-Pesa number (e.g. 0712345678).", isSuccess: false);
      return;
    }

    // Save phone for future convenience
    await DatabaseHelper.instance.updateSettings({'mpesa_number': phone});

    final shop = Provider.of<ShopProvider>(context, listen: false);

    setState(() => _isLoading = true);

    final basicAuth = (dotenv.env['PAYHERO_BASIC_AUTH']?.isNotEmpty == true)
        ? dotenv.env['PAYHERO_BASIC_AUTH']!
        : "S0dxNGcxSnZhaU1qUGFPVkFBMHo6OXUwMmpnYUkzUkhMQTJtUXhMVTg2aTg2OUd3RHo4eFNGM0JFMFJSYg==";
    final channelId = (dotenv.env['PAYHERO_CHANNEL_ID']?.isNotEmpty == true)
        ? dotenv.env['PAYHERO_CHANNEL_ID']!
        : "3145";

    final extRef = shop.generatePayHeroRef("SUB");

    final invoiceId = await PayHeroService().initiateSTKPush(
      phoneNumber: phone,
      amount: _selectedPlan.amount,
      externalReference: extRef,
      basicAuth: basicAuth,
      channelId: channelId,
    );

    setState(() => _isLoading = false);

    if (invoiceId != null && mounted) {
      _showListeningDialog(invoiceId);
    } else {
      FeedbackDialog.show(context, title: "Payment Failed", message: "Could not initiate M-Pesa STK push. Please ensure your phone is active and try again.", isSuccess: false);
    }
  }

  void _showListeningDialog(String invoiceId) {
    final shop = Provider.of<ShopProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);

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

            // PAYMENT CONFIRMED
            if (status == "PAID") {
              shop.loadSubscriptionStatus(auth.user?.uid);
              shop.refreshProStatus();

              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) {
                  Navigator.of(ctx).pop();
                  FeedbackDialog.show(
                    context,
                    title: "Pro Activated!",
                    message: "Thank you! Your ${_selectedPlan.title} is now active.",
                    isSuccess: true,
                  );
                }
              });

              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                backgroundColor: _surfaceColor,
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_outline, color: Colors.green, size: 70),
                    const SizedBox(height: 16),
                    Text("Payment Confirmed!", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: _textColor)),
                    const SizedBox(height: 6),
                    Text("Your M-Bizna Pro features have been unlocked.", textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              );
            }

            // PAYMENT FAILED
            if (status == "FAILED") {
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                backgroundColor: _surfaceColor,
                title: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 22),
                    const SizedBox(width: 8),
                    Text("Payment Cancelled", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: _textColor)),
                  ],
                ),
                content: Text("The STK push timed out or was cancelled by the user.", style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade700)),
                actions: [
                  TextButton(
                    child: Text("Dismiss", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              );
            }

            // WAITING FOR PIN
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              backgroundColor: _surfaceColor,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: _primaryOrange),
                  const SizedBox(height: 20),
                  Text("Prompting M-Pesa...", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: _textColor)),
                  const SizedBox(height: 8),
                  Text("Please enter your M-Pesa PIN on your phone to complete KES ${_selectedPlan.amount.toStringAsFixed(0)} payment.", textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 20),
                  TextButton(
                    child: Text("Cancel Payment", style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final shop = Provider.of<ShopProvider>(context);
    final isPro = shop.isProActive;
    final daysRemaining = shop.daysRemaining;

    return Scaffold(
      backgroundColor: _containerColor,
      appBar: AppBar(
        backgroundColor: _containerColor,
        elevation: 0,
        title: Text("M-Bizna Pro Subscription", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: _textColor)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Current Subscription Status Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: LinearGradient(
                  colors: isPro 
                    ? [const Color(0xFF1E824C), const Color(0xFF2ECC71)]
                    : [_primaryOrange, const Color(0xFFFF8B33)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isPro ? const Color(0xFF1E824C) : _primaryOrange).withOpacity(0.3),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
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
                          Icon(isPro ? Icons.verified : Icons.workspace_premium, color: Colors.white, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            isPro ? "PRO ACTIVE" : "FREE PLAN",
                            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.1),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(12)),
                        child: Text(
                          isPro ? "$daysRemaining days left" : "Upgrade to Pro",
                          style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isPro ? "${shop.shopName} is on M-Bizna Pro" : "Unlock Full Cloud & M-Pesa Power",
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isPro 
                      ? "Zero per-sale platform fees • Automated M-Pesa STK • Cloud Sync active."
                      : "Zero per-transaction fees. Everything included in one simple subscription.",
                    style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.9), fontSize: 12),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 2. Pro Features Included Checklist
            Text("WHAT'S INCLUDED IN PRO", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.1)),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                children: [
                  _buildBenefitRow(Icons.point_of_sale, "M-Pesa STK Push Integration", "Prompt customers on their phones with zero per-sale platform fees"),
                  const SizedBox(height: 14),
                  _buildBenefitRow(Icons.cloud_sync_outlined, "Real-time Cloud Sync & Backups", "Automatic instant cloud synchronization across all devices"),
                  const SizedBox(height: 14),
                  _buildBenefitRow(Icons.badge_outlined, "Staff Roles & Attendant Access", "Manage staff permissions with biometric and role security"),
                  const SizedBox(height: 14),
                  _buildBenefitRow(Icons.speed, "5-Pillar Health Score & PDF Reports", "Algorithmic business diagnosis and detailed PDF statement exports"),
                  const SizedBox(height: 14),
                  _buildBenefitRow(Icons.smart_toy_outlined, "M-Bizna Smart Assistant", "Natural language query engine for sales, debtors, and inventory"),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 3. Plan Selection
            Text("CHOOSE YOUR SUBSCRIPTION PLAN", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.1)),
            const SizedBox(height: 12),

            Column(
              children: _plans.map((plan) {
                final isSelected = _selectedPlan.id == plan.id;
                return GestureDetector(
                  onTap: () => setState(() => _selectedPlan = plan),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? _primaryOrange : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: Row(
                      children: [
                        Radio<String>(
                          value: plan.id,
                          groupValue: _selectedPlan.id,
                          activeColor: _primaryOrange,
                          onChanged: (_) => setState(() => _selectedPlan = plan),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(plan.title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: _textColor)),
                                  if (plan.badge != null) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(color: _primaryOrange.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                                      child: Text(plan.badge!, style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: _primaryOrange)),
                                    ),
                                  ],
                                ],
                              ),
                              Text(plan.savings, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                        Text(
                          "KES ${plan.amount.toStringAsFixed(0)}",
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: _primaryOrange),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // 4. M-Pesa Phone Number Input Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.phone_android, color: _primaryOrange, size: 18),
                      const SizedBox(width: 8),
                      Text("M-PESA NUMBER TO PAY FROM", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.1)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: _textColor),
                    decoration: InputDecoration(
                      hintText: "07XX XXX XXX",
                      prefixIcon: const Icon(Icons.dialpad, size: 18),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // 5. Submit Button (STK Push Trigger)
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                label: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(
                      "Pay KES ${_selectedPlan.amount.toStringAsFixed(0)} via M-Pesa",
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                onPressed: _isLoading ? null : _initiateSubscriptionPayment,
              ),
            ),

            const SizedBox(height: 14),

            // 6. Auto-Renew Setting
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text("Auto-Renew Subscription", style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: _textColor)),
              subtitle: Text("Prompt for renewal when days reach 0", style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
              value: shop.autoRenewEnabled,
              activeColor: _primaryOrange,
              onChanged: (val) => shop.toggleAutoRenew(val),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitRow(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: _primaryOrange.withOpacity(0.12), shape: BoxShape.circle),
          child: Icon(icon, color: _primaryOrange, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: _textColor)),
              Text(subtitle, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }
}
