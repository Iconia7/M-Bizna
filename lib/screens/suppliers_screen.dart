import 'package:duka_manager/providers/inventory_provider.dart';
import 'package:duka_manager/providers/shop_provider.dart';
import 'package:duka_manager/widgets/feedback_dialog.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/supplier.dart';
import '../providers/supplier_provider.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  _SuppliersScreenState createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  Color get _primaryOrange => const Color(0xFFFF6B00);
  Color get _surfaceColor => Theme.of(context).colorScheme.surface;
  Color get _containerColor => Theme.of(context).brightness == Brightness.light ? const Color(0xFFF5F6F9) : const Color(0xFF121212);
  Color get _cardColor => Theme.of(context).brightness == Brightness.light ? Colors.white : const Color(0xFF1E1E1E);
  Color get _textColor => Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF1A1A1A);

  @override
  void initState() {
    super.initState();
    Provider.of<SupplierProvider>(context, listen: false).loadSuppliers();
  }

  void _showAddEditSupplierDialog({Supplier? supplierToEdit}) {
    final nameCtrl = TextEditingController(text: supplierToEdit?.name ?? "");
    final phoneCtrl = TextEditingController(text: supplierToEdit?.phone ?? "");
    final companyCtrl = TextEditingController(text: supplierToEdit?.company ?? "");
    final payCtrl = TextEditingController(text: supplierToEdit?.paymentDetails ?? "");
    final notesCtrl = TextEditingController(text: supplierToEdit?.notes ?? "");

    final isEditing = supplierToEdit != null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        backgroundColor: _surfaceColor,
        title: Text(
          isEditing ? "Edit Supplier" : "Add New Supplier",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: _textColor),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInput(nameCtrl, "Contact Person / Rep", Icons.person_outline),
              const SizedBox(height: 10),
              _buildInput(phoneCtrl, "Phone (07...)", Icons.phone_outlined, isNumber: true),
              const SizedBox(height: 10),
              _buildInput(companyCtrl, "Company / Distributor", Icons.business_outlined),
              const SizedBox(height: 10),
              _buildInput(payCtrl, "Payment Info (Paybill/Till)", Icons.payment_outlined),
              const SizedBox(height: 10),
              _buildInput(notesCtrl, "Notes / Delivery Schedule", Icons.notes_outlined),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: Text("Cancel", style: GoogleFonts.poppins(color: Colors.grey)),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryOrange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(isEditing ? "Save Changes" : "Add Supplier", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () async {
              if (nameCtrl.text.trim().isNotEmpty && phoneCtrl.text.trim().isNotEmpty) {
                final supplier = Supplier(
                  id: supplierToEdit?.id,
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  company: companyCtrl.text.trim().isEmpty ? null : companyCtrl.text.trim(),
                  paymentDetails: payCtrl.text.trim().isEmpty ? null : payCtrl.text.trim(),
                  notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                );

                final provider = Provider.of<SupplierProvider>(context, listen: false);
                if (isEditing) {
                  await provider.updateSupplier(supplier);
                } else {
                  await provider.addSupplier(supplier);
                }

                Navigator.pop(ctx);
                FeedbackDialog.show(context, title: "Success", message: "${supplier.name} saved.", isSuccess: true);
              }
            },
          )
        ],
      ),
    );
  }

  Widget _buildInput(TextEditingController ctrl, String label, IconData icon, {bool isNumber = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.phone : TextInputType.text,
      style: GoogleFonts.poppins(color: _textColor, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
        prefixIcon: Icon(icon, color: _primaryOrange, size: 18),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  void _showSupplierActionSheet(Supplier supplier) {
    final supplierProvider = Provider.of<SupplierProvider>(context, listen: false);

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
            Text(
              supplier.company != null && supplier.company!.isNotEmpty ? "${supplier.company} (${supplier.name})" : supplier.name,
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: _textColor),
            ),
            Text("Phone: ${supplier.phone}", style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 20),

            // Option 1: Create Purchase Order from Low Stock
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: _primaryOrange.withOpacity(0.12), shape: BoxShape.circle),
                child: Icon(Icons.shopping_cart_checkout, color: _primaryOrange),
              ),
              title: Text("Create Purchase Order", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: _textColor, fontSize: 14)),
              subtitle: Text("Auto-populate with low stock items", style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
              onTap: () {
                Navigator.pop(ctx);
                _showPurchaseOrderBuilder(supplier);
              },
            ),

            // Option 2: Call Supplier
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.blue.withOpacity(0.12), shape: BoxShape.circle),
                child: const Icon(Icons.call, color: Colors.blue),
              ),
              title: Text("Call Supplier", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: _textColor, fontSize: 14)),
              subtitle: Text(supplier.phone, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
              onTap: () async {
                Navigator.pop(ctx);
                final uri = Uri.parse("tel:${supplier.phone}");
                if (await canLaunchUrl(uri)) launchUrl(uri);
              },
            ),

            // Option 3: Edit Details
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.grey.withOpacity(0.15), shape: BoxShape.circle),
                child: Icon(Icons.edit_outlined, color: _textColor),
              ),
              title: Text("Edit Details", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: _textColor, fontSize: 14)),
              onTap: () {
                Navigator.pop(ctx);
                _showAddEditSupplierDialog(supplierToEdit: supplier);
              },
            ),

            // Option 4: Delete
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.12), shape: BoxShape.circle),
                child: const Icon(Icons.delete_outline, color: Colors.redAccent),
              ),
              title: Text("Delete Supplier", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.redAccent, fontSize: 14)),
              onTap: () async {
                Navigator.pop(ctx);
                await supplierProvider.deleteSupplier(supplier.id!);
                FeedbackDialog.show(context, title: "Deleted", message: "Supplier removed.", isSuccess: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPurchaseOrderBuilder(Supplier supplier) {
    final inventory = Provider.of<InventoryProvider>(context, listen: false);
    final shop = Provider.of<ShopProvider>(context, listen: false);
    final supplierProvider = Provider.of<SupplierProvider>(context, listen: false);

    final lowStockItems = inventory.products.where((p) => p.stockQty <= 5).toList();
    final Map<int, double> orderQuantities = {};

    for (var p in lowStockItems) {
      orderQuantities[p.id!] = 10.0; // Suggested restock quantity
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, scrollCtrl) => Container(
            decoration: BoxDecoration(
              color: _surfaceColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
                Text("Restock Order to ${supplier.name}", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: _textColor)),
                Text("Select items and order quantities to send via WhatsApp", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 16),

                Expanded(
                  child: lowStockItems.isEmpty
                    ? Center(
                        child: Text("No low stock items detected currently.", style: GoogleFonts.poppins(color: Colors.grey)),
                      )
                    : ListView.separated(
                        controller: scrollCtrl,
                        itemCount: lowStockItems.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, i) {
                          final product = lowStockItems[i];
                          final qty = orderQuantities[product.id!] ?? 10.0;

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _containerColor),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(product.name, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: _textColor)),
                                      Text("In Stock: ${product.stockQty} ${product.unit}", style: GoogleFonts.poppins(fontSize: 11, color: Colors.redAccent)),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, size: 20),
                                      onPressed: () {
                                        if (qty > 1) {
                                          setSheetState(() => orderQuantities[product.id!] = qty - 1);
                                        }
                                      },
                                    ),
                                    Text("${qty.toInt()} ${product.unit}", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: _textColor)),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline, size: 20),
                                      onPressed: () {
                                        setSheetState(() => orderQuantities[product.id!] = qty + 1);
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.send, color: Colors.white, size: 18),
                    label: Text("Send Order via WhatsApp", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                    onPressed: () {
                      final itemsToSend = lowStockItems.map((p) {
                        return {
                          'name': p.name,
                          'qty': orderQuantities[p.id!] ?? 10.0,
                          'unit': p.unit,
                        };
                      }).toList();

                      Navigator.pop(ctx);
                      supplierProvider.sendPurchaseOrder(supplier, itemsToSend, shop.shopName);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final supplierProvider = Provider.of<SupplierProvider>(context);
    final suppliers = supplierProvider.suppliers;

    return Scaffold(
      backgroundColor: _containerColor,
      appBar: AppBar(
        backgroundColor: _containerColor,
        elevation: 0,
        title: Text("Suppliers & Restock", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 20, color: _textColor)),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: _textColor),
            onPressed: () => _showAddEditSupplierDialog(),
          ),
        ],
      ),
      body: suppliers.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.local_shipping_outlined, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text("No suppliers added yet.", style: GoogleFonts.poppins(color: Colors.grey, fontSize: 15)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: _primaryOrange),
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: Text("Add First Supplier", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                  onPressed: () => _showAddEditSupplierDialog(),
                ),
              ],
            ),
          )
        : ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: suppliers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) {
              final s = suppliers[i];

              return Container(
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: _primaryOrange.withOpacity(0.12), shape: BoxShape.circle),
                    child: Icon(Icons.local_shipping_outlined, color: _primaryOrange, size: 22),
                  ),
                  title: Text(
                    s.company != null && s.company!.isNotEmpty ? "${s.company} (${s.name})" : s.name,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: _textColor),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 2),
                      Text("Phone: ${s.phone}", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                      if (s.paymentDetails != null && s.paymentDetails!.isNotEmpty)
                        Text("Pay: ${s.paymentDetails}", style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade600)),
                    ],
                  ),
                  trailing: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                  onTap: () => _showSupplierActionSheet(s),
                ),
              );
            },
          ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _primaryOrange,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => _showAddEditSupplierDialog(),
      ),
    );
  }
}
