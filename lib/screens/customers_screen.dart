import 'package:duka_manager/db/database_helper.dart';
import 'package:duka_manager/providers/shop_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/customer_provider.dart';
import '../models/customer.dart';
import '../widgets/feedback_dialog.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  _CustomersScreenState createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  Color get _primaryOrange => const Color(0xFFFF6B00);
  Color get _surfaceColor => Theme.of(context).colorScheme.surface;
  Color get _containerColor => Theme.of(context).brightness == Brightness.light ? const Color(0xFFF5F6F9) : const Color(0xFF121212);
  Color get _cardColor => Theme.of(context).brightness == Brightness.light ? Colors.white : const Color(0xFF1E1E1E);
  Color get _textColor => Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF1A1A1A);
  static const Color whatsappGreen = Color(0xFF25D366);

  @override
  void initState() {
    super.initState();
    Provider.of<CustomerProvider>(context, listen: false).loadCustomers();
  }

  void _showAddCustomerDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final limitCtrl = TextEditingController(text: "2000");

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: _surfaceColor,
        title: Text("Add Customer", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: _textColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogInput(nameCtrl, "Name", Icons.person_outline),
            const SizedBox(height: 10),
            _buildDialogInput(phoneCtrl, "Phone (07...)", Icons.phone_outlined, isNumber: true),
            const SizedBox(height: 10),
            _buildDialogInput(limitCtrl, "Credit Limit (KES)", Icons.credit_card_outlined, isNumber: true),
          ],
        ),
        actions: [
          TextButton(
            child: Text("Cancel", style: GoogleFonts.poppins(color: Colors.grey)),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _textColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
            ),
            child: Text("Save Customer", style: GoogleFonts.poppins(color: _surfaceColor)),
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                final newC = Customer(
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  creditLimit: double.tryParse(limitCtrl.text) ?? 2000,
                );
                Provider.of<CustomerProvider>(context, listen: false).addCustomer(newC);
                Navigator.pop(ctx);
                FeedbackDialog.show(context, title: "Success", message: "${newC.name} added to list.", isSuccess: true);
              }
            },
          )
        ],
      ),
    );
  }

  void _showPayDebtDialog(Customer customer) {
    final payCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: _surfaceColor,
        title: Text("Record Debt Payment", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: _textColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Customer: ${customer.name}", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: _textColor)),
            Text("Current Debt: KES ${customer.currentDebt.toStringAsFixed(0)}", style: GoogleFonts.poppins(color: Colors.redAccent, fontSize: 13)),
            const SizedBox(height: 15),
            _buildDialogInput(payCtrl, "Amount Paid (KES)", Icons.payments_outlined, isNumber: true),
          ],
        ),
        actions: [
          TextButton(
            child: Text("Cancel", style: GoogleFonts.poppins(color: Colors.grey)),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
            ),
            child: const Text("Confirm Payment", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () async {
              final amount = double.tryParse(payCtrl.text) ?? 0.0;
              if (amount > 0) {
                await Provider.of<CustomerProvider>(context, listen: false).payDebt(customer.id!, amount);
                Navigator.pop(ctx);
                FeedbackDialog.show(context, title: "Payment Recorded", message: "Deducted KES ${amount.toStringAsFixed(0)} from ${customer.name}'s balance.", isSuccess: true);
              }
            },
          )
        ],
      ),
    );
  }

  void _showCustomerActionSheet(Customer customer) async {
    final shop = Provider.of<ShopProvider>(context, listen: false);
    final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
    final settings = await DatabaseHelper.instance.getSettings();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
            ),
            const SizedBox(height: 16),
            Text(customer.name, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: _textColor)),
            Text("Debt: KES ${customer.currentDebt.toStringAsFixed(0)} / Limit KES ${customer.creditLimit.toStringAsFixed(0)}", style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 20),

            // Option 1: WhatsApp Detailed Statement
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: whatsappGreen.withOpacity(0.12), shape: BoxShape.circle),
                child: const Icon(Icons.description_outlined, color: whatsappGreen),
              ),
              title: Text("Share Statement via WhatsApp", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: _textColor, fontSize: 14)),
              subtitle: Text("Sends full balance & M-Pesa pay details", style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
              onTap: () {
                Navigator.pop(ctx);
                customerProvider.sendWhatsAppStatement(customer, shop.shopName, settings);
              },
            ),

            // Option 2: Quick WhatsApp Reminder
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.blue.withOpacity(0.12), shape: BoxShape.circle),
                child: const Icon(Icons.notifications_active_outlined, color: Colors.blue),
              ),
              title: Text("Send Quick Reminder", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: _textColor, fontSize: 14)),
              subtitle: Text("Sends a concise reminder to pay", style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
              onTap: () {
                Navigator.pop(ctx);
                customerProvider.sendWhatsAppReminder(customer, shop.shopName);
              },
            ),

            // Option 3: View Account Ledger
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.purple.withOpacity(0.12), shape: BoxShape.circle),
                child: const Icon(Icons.receipt_long_outlined, color: Colors.purple),
              ),
              title: Text("View Account Ledger", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: _textColor, fontSize: 14)),
              subtitle: Text("Audit history of credit sales & repayments", style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
              onTap: () {
                Navigator.pop(ctx);
                _showLedgerDialog(customer);
              },
            ),

            // Option 4: Record Payment
            if (customer.currentDebt > 0)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.12), shape: BoxShape.circle),
                  child: const Icon(Icons.payments_outlined, color: Colors.green),
                ),
                title: Text("Record Payment / Repayment", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: _textColor, fontSize: 14)),
                subtitle: Text("Reduce customer's outstanding balance", style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showPayDebtDialog(customer);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showLedgerDialog(Customer customer) {
    final customerProvider = Provider.of<CustomerProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        backgroundColor: _surfaceColor,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("${customer.name}'s Ledger", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: _textColor)),
            const SizedBox(height: 4),
            Text("Balance: KES ${customer.currentDebt.toStringAsFixed(0)} (Limit: KES ${customer.creditLimit.toStringAsFixed(0)})", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: FutureBuilder(
            future: customerProvider.getCustomerLedger(customer.id!),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
              }

              final ledger = snapshot.data!;
              if (ledger.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text("No transaction history recorded yet.", style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13)),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                itemCount: ledger.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final entry = ledger[i];
                  final isCredit = entry.type == 'CREDIT_SALE';
                  final timeStr = "${entry.dateTime.day}/${entry.dateTime.month}/${entry.dateTime.year} ${entry.dateTime.hour}:${entry.dateTime.minute.toString().padLeft(2, '0')}";

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isCredit ? Colors.orange.withOpacity(0.12) : Colors.green.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isCredit ? Icons.add_circle_outline : Icons.check_circle_outline,
                            size: 16,
                            color: isCredit ? Colors.orange : Colors.green,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isCredit ? "Credit Purchase" : "Debt Repayment",
                                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: _textColor),
                              ),
                              Text(
                                "$timeStr • Bal: KES ${entry.balanceAfter.toStringAsFixed(0)}",
                                style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          "${isCredit ? '+' : '-'}KES ${entry.amount.toStringAsFixed(0)}",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isCredit ? Colors.redAccent : Colors.green,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            child: Text("Close", style: GoogleFonts.poppins(color: _primaryOrange, fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.pop(ctx),
          )
        ],
      ),
    );
  }

  Widget _buildDialogInput(TextEditingController ctrl, String label, IconData icon, {bool isNumber = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.phone : TextInputType.text,
      style: GoogleFonts.poppins(color: _textColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
        prefixIcon: Icon(icon, color: _primaryOrange, size: 18),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.withOpacity(0.3))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _primaryOrange)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customerProvider = Provider.of<CustomerProvider>(context);
    final customers = customerProvider.customers;

    final totalDebt = customers.fold<double>(0.0, (sum, c) => sum + c.currentDebt);
    final totalDebtors = customers.where((c) => c.currentDebt > 0).length;

    return Scaffold(
      backgroundColor: _containerColor,
      appBar: AppBar(
        backgroundColor: _containerColor,
        elevation: 0,
        centerTitle: false,
        title: Text("Deni Manager", style: GoogleFonts.poppins(color: _textColor, fontWeight: FontWeight.bold, fontSize: 24)),
        iconTheme: IconThemeData(color: _textColor),
      ),
      body: customers.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 60, color: Colors.grey.shade400),
                  const SizedBox(height: 10),
                  Text("No customers recorded yet", style: GoogleFonts.poppins(color: Colors.grey)),
                ],
              ),
            )
          : Column(
              children: [
                // Top Deni Summary Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Total Outstanding", style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
                            Text(
                              "KES ${totalDebt.toStringAsFixed(0)}",
                              style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.redAccent)
                            ),
                          ],
                        ),
                        Container(
                          height: 35,
                          width: 1,
                          color: Colors.grey.shade300,
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text("Active Debtors", style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
                            Text(
                              "$totalDebtors customers",
                              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: _textColor)
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Customer List
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    itemCount: customers.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) {
                      final customer = customers[i];
                      final isHighRisk = customer.currentDebt > (customer.creditLimit * 0.8);
                      final debtRatio = (customer.currentDebt / customer.creditLimit).clamp(0.0, 1.0);

                      return GestureDetector(
                        onTap: () => _showCustomerActionSheet(customer),
                        child: Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: _cardColor,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                            border: isHighRisk ? Border.all(color: Colors.red.withOpacity(0.35), width: 1.5) : null
                          ),
                          child: Row(
                            children: [
                              // Avatar
                              Container(
                                width: 48, height: 48,
                                decoration: BoxDecoration(
                                  color: isHighRisk ? Colors.red.withOpacity(0.1) : _containerColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    customer.name.isNotEmpty ? customer.name[0].toUpperCase() : "?",
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold, 
                                      fontSize: 18, 
                                      color: isHighRisk ? Colors.red : _textColor
                                    ),
                                  ),
                                ),
                              ),
                              
                              const SizedBox(width: 14),
                              
                              // Info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(customer.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15, color: _textColor)),
                                    Text(customer.phone, style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
                                    const SizedBox(height: 6),
                                    
                                    // Debt Progress Bar
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(5),
                                            child: LinearProgressIndicator(
                                              value: debtRatio,
                                              backgroundColor: _containerColor,
                                              color: isHighRisk ? Colors.red : (debtRatio > 0.5 ? _primaryOrange : Colors.green),
                                              minHeight: 5,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          "${(debtRatio * 100).toInt()}%", 
                                          style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey)
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              
                              const SizedBox(width: 12),
                              
                              // Debt & Quick Trigger
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    "KES ${customer.currentDebt.toStringAsFixed(0)}", 
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold, 
                                      fontSize: 15, 
                                      color: customer.currentDebt > 0 ? Colors.redAccent : Colors.green
                                    )
                                  ),
                                  Text("Balance", style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey)),
                                  const SizedBox(height: 8),
                                  
                                  if (customer.currentDebt > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: whatsappGreen.withOpacity(0.12), 
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.chat_bubble_outline, color: whatsappGreen, size: 12),
                                          const SizedBox(width: 4),
                                          Text("Actions", style: GoogleFonts.poppins(color: whatsappGreen, fontSize: 10, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    )
                                ],
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Theme.of(context).brightness == Brightness.light ? const Color(0xFF1A1A1A) : const Color(0xFF333333),
        elevation: 5,
        onPressed: _showAddCustomerDialog,
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
    );
  }
}