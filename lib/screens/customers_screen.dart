import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/customer_provider.dart';
import '../models/customer.dart';
import '../widgets/feedback_dialog.dart';

class CustomersScreen extends StatefulWidget {
  @override
  _CustomersScreenState createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  // 🎨 THEME COLORS (Dynamic Getters)
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
            _buildDialogInput(nameCtrl, "Name", Icons.person),
            SizedBox(height: 10),
            _buildDialogInput(phoneCtrl, "Phone", Icons.phone, isNumber: true),
            SizedBox(height: 10),
            _buildDialogInput(limitCtrl, "Credit Limit (KES)", Icons.lock, isNumber: true),
          ],
        ),
        actions: [
          TextButton(
            child: Text("Cancel", style: GoogleFonts.poppins(color: Colors.grey)),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).brightness == Brightness.light ? const Color(0xFF1A1A1A) : const Color(0xFF444444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
            ),
            child: Text("Save Customer", style: GoogleFonts.poppins(color: Colors.white)),
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                final newC = Customer(
                  name: nameCtrl.text,
                  phone: phoneCtrl.text,
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
                  SizedBox(height: 10),
                  Text("No customers recorded yet", style: GoogleFonts.poppins(color: Colors.grey)),
                ],
              ),
            )
          : ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              itemCount: customers.length,
              separatorBuilder: (ctx, i) => SizedBox(height: 15),
              itemBuilder: (ctx, i) {
                final customer = customers[i];
                final isHighRisk = customer.currentDebt > (customer.creditLimit * 0.8);
                final debtRatio = (customer.currentDebt / customer.creditLimit).clamp(0.0, 1.0);

                return Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: _cardColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                    border: isHighRisk ? Border.all(color: Colors.red.withOpacity(0.3), width: 1.5) : null
                  ),
                  child: Row(
                    children: [
                      // Avatar
                      Container(
                        width: 50, height: 50,
                        decoration: BoxDecoration(
                          color: isHighRisk ? Colors.red.withOpacity(0.1) : _containerColor,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            customer.name.isNotEmpty ? customer.name[0].toUpperCase() : "?",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold, 
                              fontSize: 20, 
                              color: isHighRisk ? Colors.red : _textColor
                            ),
                          ),
                        ),
                      ),
                      
                      SizedBox(width: 15),
                      
                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(customer.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16, color: _textColor)),
                            Text(customer.phone, style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
                            SizedBox(height: 8),
                            
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
                                      minHeight: 6,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  "${(debtRatio * 100).toInt()}% Limit", 
                                  style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey)
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      SizedBox(width: 15),
                      
                      // Debt & Action
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "KES ${customer.currentDebt.toStringAsFixed(0)}", 
                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: customer.currentDebt > 0 ? Colors.red : Colors.green)
                          ),
                          Text("Debt", style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey)),
                          SizedBox(height: 10),
                          
                          if (customer.currentDebt > 0)
                            GestureDetector(
                              onTap: () => customerProvider.sendWhatsAppReminder(customer),
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: whatsappGreen, 
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [BoxShadow(color: whatsappGreen.withOpacity(0.3), blurRadius: 5, offset: Offset(0, 2))]
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.chat, color: Colors.white, size: 14),
                                    SizedBox(width: 4),
                                    Text("Remind", style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            )
                        ],
                      )
                    ],
                  ),
                );
              },
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