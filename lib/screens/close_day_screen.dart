import 'package:duka_manager/providers/shop_provider.dart';
import 'package:duka_manager/services/printer_service.dart';
import 'package:duka_manager/widgets/feedback_dialog.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/daily_closing.dart';
import '../providers/report_provider.dart';

class CloseDayScreen extends StatefulWidget {
  const CloseDayScreen({super.key});

  @override
  _CloseDayScreenState createState() => _CloseDayScreenState();
}

class _CloseDayScreenState extends State<CloseDayScreen> {
  final TextEditingController _floatController = TextEditingController(text: "0");
  final TextEditingController _cashCountedController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  Color get _primaryOrange => const Color(0xFFFF6B00);
  Color get _surfaceColor => Theme.of(context).colorScheme.surface;
  Color get _containerColor => Theme.of(context).brightness == Brightness.light ? const Color(0xFFF5F6F9) : const Color(0xFF121212);
  Color get _cardColor => Theme.of(context).brightness == Brightness.light ? Colors.white : const Color(0xFF1E1E1E);
  Color get _textColor => Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF1A1A1A);

  DailyClosing? _currentClosing;
  bool _isLoading = true;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _recalculate();
    _floatController.addListener(_recalculate);
    _cashCountedController.addListener(_recalculate);
  }

  void _recalculate() async {
    final reportProvider = Provider.of<ReportProvider>(context, listen: false);
    final startingFloat = double.tryParse(_floatController.text) ?? 0.0;
    final actualCash = double.tryParse(_cashCountedController.text) ?? 0.0;

    final closing = await reportProvider.getClosingBreakdown(
      startingFloat: startingFloat,
      actualCash: actualCash,
      notes: _notesController.text,
    );

    if (mounted) {
      setState(() {
        _currentClosing = closing;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSaveAndClose() async {
    if (_currentClosing == null) return;

    final reportProvider = Provider.of<ReportProvider>(context, listen: false);
    final shop = Provider.of<ShopProvider>(context, listen: false);

    await reportProvider.saveDailyClosing(_currentClosing!);
    setState(() => _isSaved = true);

    _showClosingSuccessDialog(shop.shopName);
  }

  void _showClosingSuccessDialog(String shopName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        backgroundColor: _surfaceColor,
        title: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.green, size: 24),
            const SizedBox(width: 10),
            Text("Day Closed Successfully", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: _textColor)),
          ],
        ),
        content: Text(
          "Daily Z-Report has been archived. You can print the receipt or share a summary to WhatsApp.",
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade700),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.print, size: 18),
            label: Text("Print Z-Report", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            onPressed: () async {
              final printer = PrinterService();
              if (await printer.isConnected) {
                try {
                  await printer.printZReport(shopName: shopName, closing: _currentClosing!);
                  FeedbackDialog.show(context, title: "Printing", message: "Z-Report sent to printer.", isSuccess: true);
                } catch (e) {
                  FeedbackDialog.show(context, title: "Printing Error", message: "$e", isSuccess: false);
                }
              } else {
                FeedbackDialog.show(context, title: "Printer Disconnected", message: "Please configure a Bluetooth or Wi-Fi printer in Settings.", isSuccess: false);
              }
            },
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryOrange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.send, size: 16, color: Colors.white),
            label: Text("Done", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shop = Provider.of<ShopProvider>(context);

    if (_isLoading || _currentClosing == null) {
      return Scaffold(
        backgroundColor: _containerColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final c = _currentClosing!;
    final diff = c.cashDifference;
    final isCashCountEntered = _cashCountedController.text.isNotEmpty;

    Color diffColor;
    String diffStatus;
    if (!isCashCountEntered) {
      diffColor = Colors.grey;
      diffStatus = "Enter counted cash to reconcile";
    } else if (diff == 0) {
      diffColor = Colors.green;
      diffStatus = "Register Balanced (KES 0)";
    } else if (diff > 0) {
      diffColor = Colors.orange;
      diffStatus = "Cash Overage (+KES ${diff.abs().toStringAsFixed(0)})";
    } else {
      diffColor = Colors.redAccent;
      diffStatus = "Cash Shortage (-KES ${diff.abs().toStringAsFixed(0)})";
    }

    return Scaffold(
      backgroundColor: _containerColor,
      appBar: AppBar(
        backgroundColor: _containerColor,
        elevation: 0,
        title: Text("Close Business Day", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 20, color: _textColor)),
        actions: [
          IconButton(
            icon: Icon(Icons.history, color: _textColor),
            onPressed: _showPastClosingsModal,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Starting Float Input Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.savings_outlined, color: Colors.blue, size: 18),
                      const SizedBox(width: 8),
                      Text("STARTING CASH FLOAT", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.1)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _floatController,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: _textColor),
                    decoration: InputDecoration(
                      prefixText: "KES ",
                      hintText: "0",
                      prefixIcon: const Icon(Icons.attach_money, size: 18),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // 2. Financial Summary Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Daily Revenue Summary", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: _textColor)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: _primaryOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                        child: Text("Z-Report", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: _primaryOrange)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSummaryRow("Cash Sales", "KES ${c.cashSales.toStringAsFixed(0)}", Icons.payments_outlined),
                  const SizedBox(height: 10),
                  _buildSummaryRow("M-Pesa Sales", "KES ${c.mpesaSales.toStringAsFixed(0)}", Icons.phone_android_outlined),
                  const SizedBox(height: 10),
                  _buildSummaryRow("Credit (Deni) Sales", "KES ${c.creditSales.toStringAsFixed(0)}", Icons.people_outline),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  _buildSummaryRow("Gross Revenue", "KES ${c.grossSales.toStringAsFixed(0)}", Icons.receipt_long_outlined, isBold: true),
                  const SizedBox(height: 10),
                  _buildSummaryRow("Today's Expenses", "-KES ${c.totalExpenses.toStringAsFixed(0)}", Icons.money_off_outlined, color: Colors.redAccent),
                  const SizedBox(height: 10),
                  _buildSummaryRow("Net Profit", "KES ${c.netProfit.toStringAsFixed(0)}", Icons.trending_up, isBold: true, color: Colors.green),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // 3. Cash Reconciliation & Discrepancy Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: diffColor.withOpacity(0.4), width: 1.5),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.balance, color: diffColor, size: 20),
                      const SizedBox(width: 8),
                      Text("CASH RECONCILIATION", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: diffColor, letterSpacing: 1.1)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Expected Cash in Till:", style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13)),
                      Text("KES ${c.expectedCash.toStringAsFixed(0)}", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: _textColor)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text("Counted Physical Cash:", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: _textColor)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _cashCountedController,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: _textColor),
                    decoration: InputDecoration(
                      prefixText: "KES ",
                      hintText: "Enter amount counted",
                      prefixIcon: const Icon(Icons.point_of_sale_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Discrepancy Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: diffColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          diff == 0 ? Icons.check_circle_outline : Icons.info_outline,
                          color: diffColor,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            diffStatus,
                            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: diffColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // 4. Action Buttons
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isSaved ? Colors.grey : _primaryOrange,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.lock_clock, color: Colors.white, size: 20),
                label: Text(
                  _isSaved ? "Day Already Closed" : "Save & Close Day",
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                onPressed: _isSaved ? null : _handleSaveAndClose,
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: BorderSide(color: _textColor.withOpacity(0.3)),
                    ),
                    icon: Icon(Icons.print, color: _textColor, size: 18),
                    label: Text("Print Z-Report", style: GoogleFonts.poppins(color: _textColor, fontWeight: FontWeight.w600)),
                    onPressed: () async {
                      final printer = PrinterService();
                      if (await printer.isConnected) {
                        try {
                          await printer.printZReport(shopName: shop.shopName, closing: _currentClosing!);
                          FeedbackDialog.show(context, title: "Printing", message: "Z-Report sent to printer.", isSuccess: true);
                        } catch (e) {
                          FeedbackDialog.show(context, title: "Printing Error", message: "$e", isSuccess: false);
                        }
                      } else {
                        FeedbackDialog.show(context, title: "Printer Disconnected", message: "Please configure a Bluetooth or Wi-Fi printer in Settings.", isSuccess: false);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: const BorderSide(color: Color(0xFF25D366)),
                    ),
                    icon: const Icon(Icons.share, color: Color(0xFF25D366), size: 18),
                    label: Text("Share Summary", style: GoogleFonts.poppins(color: const Color(0xFF25D366), fontWeight: FontWeight.w600)),
                    onPressed: () {
                      final reportProvider = Provider.of<ReportProvider>(context, listen: false);
                      reportProvider.sendWhatsAppZReport(_currentClosing!, shop.shopName, "");
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, IconData icon, {bool isBold = false, Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: _textColor),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color ?? _textColor,
          ),
        ),
      ],
    );
  }

  void _showPastClosingsModal() {
    final reportProvider = Provider.of<ReportProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          ),
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 18),
              Text("Archived Z-Reports", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: _textColor)),
              const SizedBox(height: 12),
              Expanded(
                child: FutureBuilder<List<DailyClosing>>(
                  future: reportProvider.getPastClosings(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final closings = snapshot.data!;
                    if (closings.isEmpty) {
                      return Center(
                        child: Text("No archived closing reports found.", style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13)),
                      );
                    }

                    return ListView.separated(
                      controller: scrollCtrl,
                      itemCount: closings.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) {
                        final c = closings[i];
                        final diff = c.cashDifference;
                        final diffColor = diff == 0 ? Colors.green : (diff > 0 ? Colors.orange : Colors.redAccent);

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _containerColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(c.date, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: _textColor)),
                                  Text("Net: KES ${c.netProfit.toStringAsFixed(0)}", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("Gross: KES ${c.grossSales.toStringAsFixed(0)} (Cash: KES ${c.cashSales.toStringAsFixed(0)})", style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
                                  Text(
                                    diff == 0 ? "Balanced" : "${diff > 0 ? '+' : ''}${diff.toStringAsFixed(0)}",
                                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: diffColor),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
