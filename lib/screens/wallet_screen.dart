import 'package:duka_manager/db/database_helper.dart';
import 'package:duka_manager/providers/shop_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ☁️ Needed for Listener

import '../providers/wallet_provider.dart';
import '../services/payhero_service.dart';
import '../widgets/feedback_dialog.dart';

class WalletScreen extends StatelessWidget {
  // 🎨 THEME COLORS
  static const Color primaryOrange = Color(0xFFFF6B00);
  static const Color textDark = Color(0xFF1A1A1A);

  @override
  Widget build(BuildContext context) {
    final wallet = Provider.of<WalletProvider>(context);

    return Scaffold(
      backgroundColor: Color(0xFFF5F6F9),
      appBar: AppBar(
        title: Text("My Wallet", style: GoogleFonts.poppins(color: textDark, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textDark),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            // 1. Balance Card
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(25),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [textDark, Color(0xFF333333)]),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))]
              ),
              child: Column(
                children: [
                  Text("Available Credits", style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14)),
                  SizedBox(height: 10),
                  Text("KES ${wallet.balance.toStringAsFixed(2)}", style: GoogleFonts.poppins(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                  SizedBox(height: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryOrange,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      padding: EdgeInsets.symmetric(horizontal: 25, vertical: 12)
                    ),
                    icon: Icon(Icons.add, color: Colors.white),
                    label: Text("Top Up", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
                    onPressed: () => _showTopUpDialog(context),
                  )
                ],
              ),
            ),

            SizedBox(height: 30),
            Align(alignment: Alignment.centerLeft, child: Text("History", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18))),
            SizedBox(height: 15),

            // 2. Transaction History
            wallet.history.isEmpty 
            ? Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text("No transactions yet.", style: GoogleFonts.poppins(color: Colors.grey)),
              )
            : ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: wallet.history.length,
                // Inside WalletScreen's ListView.builder
itemBuilder: (ctx, i) {
  final tx = wallet.history[i];
  final DateTime date = (tx['date_time'] as Timestamp).toDate();
  final isDeposit = (tx['amount'] ?? 0) > 0;
  final String status = tx['status'] ?? (isDeposit ? "SUCCESS" : "PAID");

  return Card(
    elevation: 0,
    margin: EdgeInsets.only(bottom: 10),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: isDeposit ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
        child: Icon(
          isDeposit ? Icons.add_rounded : Icons.remove_rounded,
          color: isDeposit ? Colors.green : Colors.red,
          size: 20,
        ),
      ),
      title: Text(tx['description'], style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(
        "${date.day}/${date.month} - ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}",
        style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            "${isDeposit ? '+' : ''}${tx['amount'].toStringAsFixed(2)}",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: isDeposit ? Colors.green : Colors.black,
            ),
          ),
          SizedBox(height: 4),
          _buildStatusBadge(status), // 👈 Our new Badge!
        ],
      ),
    ),
  );
}
              )
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
  Color bgColor;
  Color textColor;
  String label = status;

  switch (status.toUpperCase()) {
    case 'PAID':
    case 'SUCCESS':
    case 'DEPOSIT':
      bgColor = Colors.green.withOpacity(0.1);
      textColor = Colors.green;
      label = "Success";
      break;
    case 'FAILED':
      bgColor = Colors.red.withOpacity(0.1);
      textColor = Colors.red;
      label = "Failed";
      break;
    case 'PENDING':
    case 'QUEUED':
      bgColor = Colors.orange.withOpacity(0.1);
      textColor = Colors.orange;
      label = "Pending";
      break;
    default:
      bgColor = Colors.grey.withOpacity(0.1);
      textColor = Colors.grey;
  }

  return Container(
    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      label,
      style: GoogleFonts.poppins(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
    ),
  );
}

  // --- 1. INPUT DIALOG ---
  void _showTopUpDialog(BuildContext context) {
    final phoneCtrl = TextEditingController();
    final amountCtrl = TextEditingController(text: "50");

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Top Up Wallet", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Enter your M-Pesa number to buy credits.", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
            SizedBox(height: 15),
            TextField(
              controller: phoneCtrl, 
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: "M-Pesa Number", 
                prefixIcon: Icon(Icons.phone, color: primaryOrange),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))
              )
            ),
            SizedBox(height: 10),
            TextField(
              controller: amountCtrl, 
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Amount (Min 50)", 
                prefixIcon: Icon(Icons.money, color: primaryOrange),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))
              )
            ),
          ],
        ),
        actions: [
          TextButton(child: Text("Cancel", style: TextStyle(color: Colors.grey)), onPressed: () => Navigator.pop(ctx)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: textDark),
            child: Text("Pay Now", style: TextStyle(color: Colors.white)),
            onPressed: () async {
  double amount = double.tryParse(amountCtrl.text) ?? 0;
  if (amount < 50) {
    FeedbackDialog.show(context, title: "Error", message: "Minimum is KES 50", isSuccess: false);
    return;
  }
  
  // Get the shopId from ShopProvider
final shop = Provider.of<ShopProvider>(context, listen: false);
  
  Navigator.pop(ctx);

  final settings = await DatabaseHelper.instance.getSettings();
  
  // 🚀 Trigger STK Push with TOPUP prefix
String? invoiceId = await PayHeroService().initiateSTKPush(
  phoneNumber: phoneCtrl.text, 
  amount: amount,
  // 👇 This generates "TOPUP|SHOP-12345|1766..."
  externalReference: shop.generatePayHeroRef("TOPUP"), 
  basicAuth: settings['payhero_auth'],      // 🚀 From User Settings
  channelId: settings['payhero_channel_id'], // 🚀 From User Settings
);
  
  if (invoiceId != null) {
    _showListeningDialog(context, invoiceId, amount);
  } else {
    FeedbackDialog.show(context, title: "Failed", message: "Could not send request.", isSuccess: false);
  }
},
          )
        ],
      ),
    );
  }

  // --- 2. LISTENING DIALOG (The Secure Check) ---
  void _showListeningDialog(BuildContext context, String invoiceId, double amount) {
    showDialog(
      context: context,
      barrierDismissible: false, // Force them to wait
      builder: (ctx) {
        return StreamBuilder<DocumentSnapshot>(
          // Listen to the specific invoice in Firestore
          stream: FirebaseFirestore.instance.collection('payment_requests').doc(invoiceId).snapshots(),
          builder: (context, snapshot) {
            
            String status = "PENDING";
            if (snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>;
              status = data['status'] ?? "PENDING";
            }

            // ✅ SUCCESS: Money Received
            if (status == "PAID") {
              // Now it is safe to add money to the local wallet
              Future.delayed(Duration.zero, () {
                 Provider.of<WalletProvider>(context, listen: false).deposit(amount);
                 Navigator.pop(ctx); // Close Dialog
                 FeedbackDialog.show(context, title: "Success", message: "Wallet recharged!", isSuccess: true);
              });

              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 60),
                    SizedBox(height: 20),
                    Text("Payment Confirmed!", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            }

            // ❌ FAILED
            if (status == "FAILED") {
              return AlertDialog(
                title: Text("Payment Failed"),
                content: Text("The transaction was cancelled or failed."),
                actions: [
                  TextButton(child: Text("Close"), onPressed: () => Navigator.pop(ctx))
                ],
              );
            }

            // ⏳ WAITING
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: primaryOrange),
                  SizedBox(height: 20),
                  Text("Waiting for M-Pesa...", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  SizedBox(height: 10),
                  Text("Please enter your PIN", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                  SizedBox(height: 20),
                  TextButton(
                    child: Text("Cancel", style: TextStyle(color: Colors.red)),
                    onPressed: () => Navigator.pop(ctx),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }
}