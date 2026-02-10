import 'dart:io';
import 'package:duka_manager/db/database_helper.dart';
import 'package:duka_manager/providers/auth_provider.dart';
import 'package:duka_manager/providers/shop_provider.dart';
import 'package:duka_manager/providers/wallet_provider.dart';
import 'package:duka_manager/screens/wallet_screen.dart';
import 'package:duka_manager/services/printer_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ☁️ Needed for Listener

import '../providers/inventory_provider.dart';
import '../providers/sales_provider.dart';
import '../providers/report_provider.dart';
import '../services/payhero_service.dart'; // 💳 Import PayHero
import '../services/sync_service.dart';    // ☁️ Import Sync
import '../models/product.dart';
import 'add_product_screen.dart';
import '../widgets/simple_scanner_page.dart';
import '../widgets/feedback_dialog.dart';

class POSScreen extends StatefulWidget {
  const POSScreen({super.key});

  @override
  _POSScreenState createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> {
  // 🎨 THEME COLORS
  static const Color primaryOrange = Color(0xFFFF6B00);
  static const Color textDark = Color(0xFF1A1A1A);
  static const Color cardGray = Color(0xFFF5F6F9);

  // --- 1. CORE POS LOGIC (Scanning & Cart) ---

  void _showProductSearch(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows full height
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Handle Bar
                Container(
                  margin: EdgeInsets.symmetric(vertical: 10),
                  width: 40, height: 5,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))
                ),
                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Text("Quick Select", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: textDark)),
                ),
                // Search Bar - We will implement a simple filter locally
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: "Search items (e.g. Sugar, Rice)...",
                      prefixIcon: Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: cardGray,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                      contentPadding: EdgeInsets.symmetric(vertical: 0)
                    ),
                    onChanged: (val) {
                      // In a real app, update the list state here
                      // For this demo, we rely on the list below being scrollable
                    },
                  ),
                ),
                SizedBox(height: 10),
                
                // THE LIST
                Expanded(
                  child: Consumer<InventoryProvider>(
                    builder: (ctx, inventory, _) {
                      final products = inventory.products;
                      return GridView.builder(
                        controller: controller, // Link to DraggableSheet
                        padding: EdgeInsets.all(20),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3, // 3 items per row
                          childAspectRatio: 0.8,
                          crossAxisSpacing: 15,
                          mainAxisSpacing: 15,
                        ),
                        itemCount: products.length,
                        itemBuilder: (ctx, i) {
                          final product = products[i];
                          return GestureDetector(
                            onTap: () {
                              Provider.of<SalesProvider>(context, listen: false).addToCart(product);
                              Navigator.pop(ctx); // Close and go back to POS
                              FeedbackDialog.show(context, title: "Added", message: "${product.name}", isSuccess: true);
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: cardGray),
                                boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 5)]
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Icon / Image
                                  Container(
                                    height: 40, width: 40,
                                    decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
                                    child: Center(child: Text(product.name[0].toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, color: primaryOrange))),
                                  ),
                                  SizedBox(height: 10),
                                  // Name
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 5),
                                    child: Text(product.name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500)),
                                  ),
                                  SizedBox(height: 5),
                                  // Price
                                  Text("KES ${product.sellPrice.toInt()}", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  void _scanAndAddToCart(BuildContext context) async {
    final inventory = Provider.of<InventoryProvider>(context, listen: false);
    final sales = Provider.of<SalesProvider>(context, listen: false);

    final scannedCode = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SimpleScannerPage()),
    );

    if (scannedCode != null) {
      final product = inventory.findByBarcode(scannedCode);
      if (product != null) {
        if (product.stockQty > 0) {
          sales.addToCart(product);
          FeedbackDialog.show(context, title: "Added", message: "${product.name}", isSuccess: true);
        } else {
          FeedbackDialog.show(context, title: "Out of Stock", message: "Cannot sell ${product.name}", isSuccess: false);
        }
      } else {
        _showAddProductDialog(context, scannedCode);
      }
    }
  }

  void _showAddProductDialog(BuildContext context, String barcode) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Unknown Item", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textDark)),
        content: Text("Add this item to inventory now?", style: GoogleFonts.poppins(color: Colors.grey)),
        actions: [
          TextButton(
            child: Text("Cancel", style: GoogleFonts.poppins(color: Colors.grey)),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: textDark, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text("Add Now", style: GoogleFonts.poppins(color: Colors.white)),
            onPressed: () async {
              Navigator.pop(ctx);
              final newProduct = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddProductScreen(initialBarcode: barcode)),
              );
              if (newProduct != null && newProduct is Product) {
                Provider.of<SalesProvider>(context, listen: false).addToCart(newProduct);
                FeedbackDialog.show(context, title: "Ready", message: "Item saved and added to cart.", isSuccess: true);
              }
            },
          ),
        ],
      ),
    );
  }

// Inside _POSScreenState

void _showManualMpesaInstruction(String? phoneNumber) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text("Manual M-Pesa", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Ask customer to pay to:"),
          SizedBox(height: 10),
          Text(phoneNumber ?? "No Number Set", style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: primaryOrange)),
          SizedBox(height: 20),
          Text("Once you receive the M-Pesa SMS, click confirm to finish.", textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Cancel")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          onPressed: () {
            Navigator.pop(ctx);
            _finalizeSale("M-Pesa (Manual)"); 
          },
          child: Text("Confirm Received", style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
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

  // 2. 🚨 CRITICAL FIX: If settings are empty, ask for the number!
  if (mpesaNumber == null || mpesaNumber.trim().isEmpty) {
    _showNumberRequiredDialog(); // Create a small dialog to collect the number
    return;
  }

  // Trigger STK Push with SUB prefix
  // ExternalReference will look like: "SUB|SHOP-12345|1735500000"
  String? invoiceId = await PayHeroService().initiateSTKPush(
    phoneNumber: settings['mpesa_number'] ?? "", 
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

void _handleCheckout() async {
  // 1. Get Settings from Database
  final settings = await DatabaseHelper.instance.getSettings();
  final shop = Provider.of<ShopProvider>(context, listen: false);
  
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      padding: EdgeInsets.all(25),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text("Select Payment Method", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
          ListTile(
            leading: Icon(Icons.money, color: Colors.green),
            title: Text("Cash"),
            onTap: () { Navigator.pop(ctx); _finalizeSale("Cash"); },
          ),
          ListTile(
            leading: Icon(Icons.phone_android, color: Colors.green),
            title: Text("M-Pesa"),
            onTap: () {
              Navigator.pop(ctx);

              if (settings['mpesa_mode'] == 'Automated' && !shop.isProActive) {
    _showSubscriptionRequiredDialog(); // 👈 Block the user
    return;
  }
              // 🚀 HYBRID TRIGGER: Decides based on settings
              if (settings['mpesa_mode'] == 'Automated') {
                _showMpesaPhoneInput(); 
              } else {
                _showManualMpesaInstruction(settings['mpesa_number']);
              }
            },
          ),
        ],
      ),
    ),
  );
}

  void _showLowBalanceDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Insufficient Credits"),
        content: Text("Using M-Pesa integration costs KES 2.00 per sale.\nPlease top up your wallet."),
        actions: [
          TextButton(child: Text("Close"), onPressed: () => Navigator.pop(ctx)),
          ElevatedButton(
            child: Text("Top Up Now"),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (c) => WalletScreen()));
            },
          )
        ],
      ),
    );
  }

  // Step A: Get Phone Number
  void _showMpesaPhoneInput() {
    final phoneController = TextEditingController();
    final wallet = Provider.of<WalletProvider>(context, listen: false);
    if (!wallet.canAfford(WalletProvider.COST_MPESA_SALE)) {
      _showLowBalanceDialog();
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("M-Pesa Payment", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Enter customer phone to send STK Push", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
            SizedBox(height: 15),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              autofocus: true,
              decoration: InputDecoration(
                hintText: "07XX XXX XXX",
                filled: true,
                fillColor: cardGray,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                prefixIcon: Icon(Icons.dialpad, color: primaryOrange),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text("Request Payment", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
            onPressed: () async {
  final sales = Provider.of<SalesProvider>(context, listen: false);
final shop = Provider.of<ShopProvider>(context, listen: false);
  
  Navigator.pop(ctx);
  
  // 🚀 Trigger STK Push with SALE prefix
final settings = await DatabaseHelper.instance.getSettings();

String? invoiceId = await PayHeroService().initiateSTKPush(
  phoneNumber: phoneController.text, 
  amount: sales.totalAmount,
  externalReference: shop.generatePayHeroRef("SALE"),
  basicAuth: settings['payhero_auth'],      // 🚀 From User Settings
  channelId: settings['payhero_channel_id'], // 🚀 From User Settings
);

  if (invoiceId != null) {
    _showListeningDialog(invoiceId);
  } else {
    FeedbackDialog.show(context, title: "Error", message: "Connection failed.", isSuccess: false);
  }
},
          )
        ],
      )
    );
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

  // Step C: The Real-Time Listener (Magic Part)
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
                Navigator.of(ctx).pop();
                _finalizeSale("M-Pesa (Pro)"); // Auto-complete sale
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


  void _showQuantityEditDialog(String barcode, double currentQty, String unit) {
  final controller = TextEditingController(text: currentQty.toString());
  
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text("Edit Quantity ($unit)", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
      content: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        autofocus: true,
        decoration: InputDecoration(
          filled: true,
          fillColor: cardGray,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          suffixText: unit,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: primaryOrange),
          onPressed: () {
            final newQty = double.tryParse(controller.text) ?? currentQty;
            Provider.of<SalesProvider>(context, listen: false).updateQuantity(barcode, newQty);
            Navigator.pop(ctx);
          },
          child: const Text("Update", style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
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

  // --- 3. FINALIZE SALE (Used by both Cash & M-Pesa) ---

void _finalizeSale(String method) async {
    final sales = Provider.of<SalesProvider>(context, listen: false);
    final inventory = Provider.of<InventoryProvider>(context, listen: false);
    final shop = Provider.of<ShopProvider>(context, listen: false); // 👈 Needed to check Pro status

    // 📝 STEP 0: Capture Receipt Data (Before clearing cart)
    final double totalAmount = sales.totalAmount;
    final List<Map<String, dynamic>> receiptItems = sales.cart.values.map((item) => {
      'name': item.product.name,
      'qty': item.quantity,
      'price': item.product.sellPrice * item.quantity
    }).toList();

    // 💾 STEP 1: Save to Local SQLite
    await sales.submitOrder(); 
    
    // 🔄 STEP 2: Refresh Inventory & Reports UI
    await inventory.loadProducts(isPro: shop.isProActive);
    await Provider.of<ReportProvider>(context, listen: false).loadDashboardStats();

    // 💰 STEP 3: Handle Cloud Sync (Subscription Based)
    // We no longer deduct KES 2.00 here. 
    // We only trigger background sync if they have an active Pro subscription.
    if (shop.isProActive) {
      try {
        await SyncService().syncSales(shop.shopId);
        debugPrint("Pro Sale synced to cloud successfully");
      } catch (e) {
        debugPrint("Background sync failed: $e. Sale remains safe in local DB.");
      }
    }

    // 🖨️ STEP 4: Show Success Dialog
    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 60),
            const SizedBox(height: 10),
            Text("Sale Complete!", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          "Paid via $method\nTotal: KES ${totalAmount.toInt()}", 
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 14)
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.print, color: Colors.black),
            label: const Text("Print Receipt", style: TextStyle(color: Colors.black)),
            onPressed: () async {
              final printer = PrinterService();
              if (await printer.isConnected) {
                await printer.printReceipt(
                  shopName: shop.shopName,
                  date: DateTime.now().toString().substring(0, 16),
                  items: receiptItems,
                  total: totalAmount,
                );
                Navigator.pop(ctx);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("No printer connected."))
                );
              }
            },
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B00), 
              shape: const StadiumBorder(),
            ),
            child: const Text("New Sale", style: TextStyle(color: Colors.white)),
            onPressed: () => Navigator.pop(ctx),
          )
        ],
      ),
    );
}

  // --- UI BUILD ---

  @override
  Widget build(BuildContext context) {
    final sales = Provider.of<SalesProvider>(context);

    return Scaffold(
      backgroundColor: cardGray,
      appBar: AppBar(
        backgroundColor: cardGray,
        elevation: 0,
        centerTitle: false,
        title: Text("Terminal", style: GoogleFonts.poppins(color: textDark, fontWeight: FontWeight.bold, fontSize: 24)),
        actions: [
          if (sales.cart.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: () => setState(() => sales.cart.clear()),
            )
        ],
      ),
      body: Column(
        children: [
          // 1. Cart List
          Expanded(
            child: sales.cart.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    itemCount: sales.cart.length,
                    separatorBuilder: (ctx, i) => SizedBox(height: 15),
                    itemBuilder: (ctx, i) {
                      final cartItem = sales.cart.values.toList()[i];
                      return Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 4))]),
                        child: Row(
                          children: [
                            Container(width: 60, height: 60, decoration: BoxDecoration(color: cardGray, borderRadius: BorderRadius.circular(15), image: cartItem.product.imagePath != null ? DecorationImage(image: FileImage(File(cartItem.product.imagePath!)), fit: BoxFit.cover) : null), child: cartItem.product.imagePath == null ? Icon(Icons.shopping_bag_outlined, color: Colors.grey.shade400) : null),
                            SizedBox(width: 15),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(cartItem.product.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15, color: textDark)), Text("KES ${cartItem.product.sellPrice}", style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13))])),
                            Container(
  decoration: BoxDecoration(color: cardGray, borderRadius: BorderRadius.circular(30)),
  child: Row(
    children: [
      _qtyBtn(Icons.remove, () => sales.removeSingleItem(cartItem.product.barcode)),
      // 🚀 Clickable Quantity for Decimal Input
      GestureDetector(
        onTap: () => _showQuantityEditDialog(
          cartItem.product.barcode, 
          cartItem.quantity, 
          cartItem.product.unit // Using the new 'unit' field
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Text(
            // Format to show decimals only when they exist (e.g. 1.5 instead of 1.50)
            cartItem.quantity.toStringAsFixed(cartItem.quantity.truncateToDouble() == cartItem.quantity ? 0 : 2),
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textDark),
          ),
        ),
      ),
      _qtyBtn(Icons.add, () => sales.addToCart(cartItem.product)),
    ],
  ),
)
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // 2. Checkout Dock
          Container(
            padding: EdgeInsets.all(25),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 30, offset: Offset(0, -5))]),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Total", style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey)), Text("KES ${sales.totalAmount.toStringAsFixed(0)}", style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: textDark))]),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(flex: 1, child: GestureDetector(onTap: () => _scanAndAddToCart(context), child: Container(height: 55, decoration: BoxDecoration(color: cardGray, borderRadius: BorderRadius.circular(18)), child: Icon(Icons.qr_code_scanner, color: textDark)))),
                      SizedBox(width: 15),
                      Expanded(
                        flex: 1, 
                        child: GestureDetector(
                          onTap: () => _showProductSearch(context), 
                          child: Container(
                            height: 55, 
                            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(18)), 
                            child: Icon(Icons.search, color: Colors.blue)
                          )
                        )
                      ),

                      SizedBox(width: 10),
                      Expanded(
                        flex: 3,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: primaryOrange, foregroundColor: Colors.white, elevation: 0, fixedSize: Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), shadowColor: primaryOrange.withOpacity(0.4)),
                          onPressed: sales.cart.isEmpty ? null : _handleCheckout, // 👈 Calls our new Logic
                          child: Text("Checkout", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 80), 
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: Container(padding: EdgeInsets.all(8), child: Icon(icon, size: 16, color: Colors.grey.shade700)));
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(padding: EdgeInsets.all(25), decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Icon(Icons.point_of_sale, size: 60, color: Colors.grey.shade300)), SizedBox(height: 20), Text("Ready to Sell?", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade400)), SizedBox(height: 10), TextButton.icon(onPressed: () => _scanAndAddToCart(context), icon: Icon(Icons.qr_code_scanner, color: primaryOrange), label: Text("Scan First Item", style: GoogleFonts.poppins(color: primaryOrange, fontWeight: FontWeight.bold)))])
    );
  }
}