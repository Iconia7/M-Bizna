import 'dart:io';
import 'package:duka_manager/db/database_helper.dart';
import 'package:duka_manager/providers/shop_provider.dart';
import 'package:duka_manager/screens/subscription_screen.dart';
import 'package:duka_manager/services/printer_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ☁️ Needed for Listener

import 'package:intl/intl.dart';
import '../providers/inventory_provider.dart';
import '../providers/sales_provider.dart';
import '../providers/report_provider.dart';
import '../services/payhero_service.dart';
import '../services/sync_service.dart';
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
  // 🎨 THEME COLORS (Dynamic Getters)
  Color get _primaryOrange => const Color(0xFFFF6B00);
  Color get _surfaceColor => Theme.of(context).colorScheme.surface;
  Color get _containerColor => Theme.of(context).brightness == Brightness.light ? const Color(0xFFF5F6F9) : Colors.white.withOpacity(0.05);
  Color get _cardColor => Theme.of(context).brightness == Brightness.light ? Colors.white : const Color(0xFF1E1E1E);
  Color get _textColor => Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF1A1A1A);

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
              color: _surfaceColor,
              borderRadius: BorderRadius.circular(20).copyWith(bottomLeft: Radius.zero, bottomRight: Radius.zero),
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
                  child: Text("Quick Select", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: _textColor)),
                ),
                // Search Bar - We will implement a simple filter locally
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: "Search items (e.g. Sugar, Rice)...",
                      hintStyle: GoogleFonts.poppins(color: Colors.grey.shade500),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: _containerColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0)
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
                                color: _cardColor,
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: _containerColor),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Icon / Image
                                  Container(
                                    height: 40, width: 40,
                                    decoration: BoxDecoration(color: _primaryOrange.withOpacity(0.1), shape: BoxShape.circle),
                                    child: Center(child: Text(product.name[0].toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold, color: _primaryOrange))),
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
        title: Text("Unknown Item", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: _textColor)),
        content: Text("Add this item to inventory now?", style: GoogleFonts.poppins(color: Colors.grey)),
        actions: [
          TextButton(
            child: Text("Cancel", style: GoogleFonts.poppins(color: Colors.grey)),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _textColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text("Add Now", style: GoogleFonts.poppins(color: _surfaceColor)),
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
          Text(phoneNumber ?? "No Number Set", style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: _primaryOrange)),
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

  // We use a fixed amount of 250 for the monthly subscription
  const double subAmount = 250.0;
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
  );

  if (invoiceId != null) {
    if (!mounted) return;
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
      decoration: BoxDecoration(
        color: _surfaceColor, 
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)],
      ),
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

  // Step A: Get Customer Phone Number and Trigger Direct STK Push
  void _showMpesaPhoneInput() {
    final phoneController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("M-Pesa Payment", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Enter customer phone to send STK Push", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 15),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              autofocus: true,
              style: TextStyle(color: _textColor),
              decoration: InputDecoration(
                hintText: "07XX XXX XXX",
                filled: true,
                fillColor: _containerColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                prefixIcon: Icon(Icons.dialpad, color: _primaryOrange),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _primaryOrange, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text("Request Payment", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
            onPressed: () async {
              final sales = Provider.of<SalesProvider>(context, listen: false);
              final shop = Provider.of<ShopProvider>(context, listen: false);
              
              Navigator.pop(ctx);
              
              // Trigger Customer Sale STK Push (Zero platform deduction)
              final settings = await DatabaseHelper.instance.getSettings();

              final effectiveChannel = (settings['payhero_channel_id'] != null && settings['payhero_channel_id'].toString().trim().isNotEmpty)
                  ? settings['payhero_channel_id'].toString().trim()
                  : (shop.payheroChannelId.isNotEmpty ? shop.payheroChannelId : null);

              String? invoiceId = await PayHeroService().initiateSTKPush(
                phoneNumber: phoneController.text, 
                amount: sales.totalAmount,
                externalReference: shop.generatePayHeroRef("SALE"),
                basicAuth: settings['payhero_auth'] ?? "",      
                channelId: effectiveChannel, 
              );

              if (invoiceId != null) {
                if (!mounted) return;
                _showListeningDialog(invoiceId);
              } else {
                FeedbackDialog.show(context, title: "Error", message: "Connection failed. Please check customer phone number.", isSuccess: false);
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
                  CircularProgressIndicator(color: _primaryOrange),
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
          fillColor: _containerColor,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          suffixText: unit,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _primaryOrange),
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
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      backgroundColor: _surfaceColor,
      title: Row(
        children: [
          Icon(Icons.workspace_premium, color: _primaryOrange, size: 24),
          const SizedBox(width: 8),
          Text("Upgrade to Pro", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: _textColor)),
        ],
      ),
      content: Text(
        "M-Pesa STK Push and Cloud Sync are available with M-Bizna Pro. Zero per-transaction fees!",
        style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade700),
      ),
      actions: [
        TextButton(
          child: Text("Later", style: GoogleFonts.poppins(color: Colors.grey)),
          onPressed: () => Navigator.pop(ctx),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryOrange,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.star, color: Colors.white, size: 16),
          label: Text("View Plans & Subscribe", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
          onPressed: () {
            Navigator.pop(ctx);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
          },
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
                try {
                  await printer.printReceipt(
                    shopName: shop.shopName,
                    date: DateTime.now().toString().substring(0, 16),
                    items: receiptItems,
                    total: totalAmount,
                  );
                  Navigator.pop(ctx);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Printing error: $e"), backgroundColor: Colors.red),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("No printer connected. Configure in Printer Settings.")),
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

  void _holdSale(BuildContext context) {
    final sales = Provider.of<SalesProvider>(context, listen: false);
    if (sales.cart.isEmpty) return;

    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.pause_circle_outline, color: _primaryOrange),
            const SizedBox(width: 8),
            Text("Hold Current Sale", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: _textColor)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Park this cart of ${sales.cart.length} items (KES ${sales.totalAmount.toStringAsFixed(0)}) to serve another customer?",
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              decoration: InputDecoration(
                hintText: "Optional Note (e.g. Customer in red hat)",
                hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey.shade400),
                filled: true,
                fillColor: _containerColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel", style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryOrange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              final success = sales.holdCurrentCart(note: noteController.text.trim().isNotEmpty ? noteController.text.trim() : null);
              if (success) {
                FeedbackDialog.show(context, title: "Sale Held", message: "Cart parked. You can resume it anytime.", isSuccess: true);
              }
            },
            child: const Text("Hold Cart", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showHeldSalesModal(BuildContext context) {
    final sales = Provider.of<SalesProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.history_toggle_off, color: _primaryOrange),
                    const SizedBox(width: 8),
                    Text("Parked / Held Sales", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: _textColor)),
                  ],
                ),
                Text("${sales.heldSalesCount} active", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 15),
            if (sales.heldSales.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text("No held sales at this time.", style: GoogleFonts.poppins(color: Colors.grey)),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: sales.heldSales.length,
                  separatorBuilder: (c, i) => const SizedBox(height: 10),
                  itemBuilder: (c, i) {
                    final held = sales.heldSales[i];
                    final timeStr = DateFormat('h:mm a').format(held.heldAt);

                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _containerColor),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _primaryOrange.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.shopping_bag_outlined, color: _primaryOrange, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "KES ${held.totalAmount.toStringAsFixed(0)}",
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: _textColor),
                                ),
                                Text(
                                  "${held.itemCount} items • Held at $timeStr",
                                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
                                ),
                                if (held.note != null && held.note!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      held.note!,
                                      style: GoogleFonts.poppins(fontSize: 11, color: _primaryOrange, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                            onPressed: () {
                              sales.deleteHeldSale(held.id);
                              Navigator.pop(ctx);
                              FeedbackDialog.show(context, title: "Removed", message: "Held sale discarded.", isSuccess: true);
                            },
                          ),
                          const SizedBox(width: 4),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryOrange,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              sales.resumeHeldSale(held.id);
                              FeedbackDialog.show(context, title: "Resumed", message: "Cart restored to terminal.", isSuccess: true);
                            },
                            child: const Text("Resume", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- UI BUILD ---

  @override
  Widget build(BuildContext context) {
    final sales = Provider.of<SalesProvider>(context);

    return Scaffold(
      backgroundColor: _surfaceColor,
      appBar: AppBar(
        backgroundColor: _surfaceColor,
        elevation: 0,
        centerTitle: false,
        title: Text("Terminal", style: GoogleFonts.poppins(color: _textColor, fontWeight: FontWeight.bold, fontSize: 24)),
        actions: [
          // 1. Held Sales Badge Chip
          if (sales.heldSalesCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () => _showHeldSalesModal(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _primaryOrange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _primaryOrange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.history_toggle_off, color: _primaryOrange, size: 16),
                      const SizedBox(width: 4),
                      Text("Held (${sales.heldSalesCount})", style: GoogleFonts.poppins(color: _primaryOrange, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),

          // 2. Hold Current Sale Action
          if (sales.cart.isNotEmpty)
            IconButton(
              tooltip: "Hold Sale",
              icon: Icon(Icons.pause_circle_outline, color: _textColor),
              onPressed: () => _holdSale(context),
            ),

          // 3. Clear Cart Action
          if (sales.cart.isNotEmpty)
            IconButton(
              tooltip: "Clear Cart",
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: () => setState(() => sales.cart.clear()),
            ),
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
                        decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 4))]),
                        child: Row(
                          children: [
                            Container(width: 60, height: 60, decoration: BoxDecoration(color: _containerColor, borderRadius: BorderRadius.circular(15), image: cartItem.product.imagePath != null ? DecorationImage(image: FileImage(File(cartItem.product.imagePath!)), fit: BoxFit.cover) : null), child: cartItem.product.imagePath == null ? Icon(Icons.shopping_bag_outlined, color: Colors.grey.shade400) : null),
                            SizedBox(width: 15),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(cartItem.product.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15, color: _textColor)), Text("KES ${cartItem.product.sellPrice}", style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13))])),
                            Container(
  decoration: BoxDecoration(color: _containerColor, borderRadius: BorderRadius.circular(30)),
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
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: _textColor),
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
            decoration: BoxDecoration(
              color: _surfaceColor, 
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)), 
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 30, offset: const Offset(0, -5))]
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Total", style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey)), Text("KES ${sales.totalAmount.toStringAsFixed(0)}", style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: _textColor))]),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(flex: 1, child: GestureDetector(onTap: () => _scanAndAddToCart(context), child: Container(height: 55, decoration: BoxDecoration(color: _containerColor, borderRadius: BorderRadius.circular(18)), child: Icon(Icons.qr_code_scanner, color: _textColor)))),
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
                          style: ElevatedButton.styleFrom(backgroundColor: _primaryOrange, foregroundColor: Colors.white, elevation: 0, fixedSize: Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), shadowColor: _primaryOrange.withOpacity(0.4)),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, 
        children: [
          Container(
            padding: EdgeInsets.all(25), 
            decoration: BoxDecoration(color: _cardColor, shape: BoxShape.circle), 
            child: Icon(Icons.point_of_sale, size: 60, color: Colors.grey.shade300)
          ), 
          SizedBox(height: 20), 
          Text("Ready to Sell?", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade400)), 
          SizedBox(height: 10), 
          TextButton.icon(
            onPressed: () => _scanAndAddToCart(context), 
            icon: Icon(Icons.qr_code_scanner, color: _primaryOrange), 
            label: Text("Scan First Item", style: GoogleFonts.poppins(color: _primaryOrange, fontWeight: FontWeight.bold))
          )
        ]
      )
    );
  }
}