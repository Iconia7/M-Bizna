import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/inventory_provider.dart';
import '../models/product.dart';
import 'add_product_screen.dart';
import '../widgets/simple_scanner_page.dart';
import '../widgets/feedback_dialog.dart';
import '../providers/shop_provider.dart';

class InventoryScreen extends StatefulWidget {
  @override
  _InventoryScreenState createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  // 1. Search & Filter State
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String _sortBy = "name"; // Options: name, price_high, stock_low

  // 🎨 THEME COLORS (Dynamic Getters)
  Color get _primaryOrange => const Color(0xFFFF6B00);
  Color get _surfaceColor => Theme.of(context).colorScheme.surface;
  Color get _containerColor => Theme.of(context).brightness == Brightness.light ? const Color(0xFFF5F6F9) : const Color(0xFF121212);
  Color get _cardColor => Theme.of(context).brightness == Brightness.light ? Colors.white : const Color(0xFF1E1E1E);
  Color get _textColor => Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF1A1A1A);

  @override
  void initState() {
    super.initState();
    final shop = Provider.of<ShopProvider>(context, listen: false);
    Provider.of<InventoryProvider>(context, listen: false).loadProducts(isPro: shop.isProActive);
    // Listen to search input changes
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  // 2. Filter Logic
  List<Product> _getFilteredProducts(List<Product> allProducts) {
    // Filter by Search
    List<Product> filtered = allProducts.where((p) {
      return p.name.toLowerCase().contains(_searchQuery) || 
             p.barcode.contains(_searchQuery);
    }).toList();

    // Sort
    switch (_sortBy) {
      case 'price_high':
        filtered.sort((a, b) => b.sellPrice.compareTo(a.sellPrice));
        break;
      case 'stock_low':
        filtered.sort((a, b) => a.stockQty.compareTo(b.stockQty)); // Low stock first
        break;
      case 'name':
      default:
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
    }
    return filtered;
  }

  void _handleQuickEntry() async {
    final scannedCode = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SimpleScannerPage()),
    );
    
    if (!mounted) return;

    if (scannedCode != null) {
      final inventory = Provider.of<InventoryProvider>(context, listen: false);
      final existingProduct = inventory.findByBarcode(scannedCode);

      if (existingProduct != null) {
        FeedbackDialog.show(
          context,
          title: "Item Found",
          message: "${existingProduct.name}\nPrice: KES ${existingProduct.sellPrice}\nStock: ${existingProduct.stockQty}",
          isSuccess: true,
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AddProductScreen(initialBarcode: scannedCode)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inventory = Provider.of<InventoryProvider>(context);
    final displayList = _getFilteredProducts(inventory.products);

    return Scaffold(
      backgroundColor: _containerColor,
      appBar: AppBar(
        backgroundColor: _containerColor,
        elevation: 0,
        centerTitle: false,
        // 3. Toggle between Title and Search Field
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: GoogleFonts.poppins(color: _textColor),
                decoration: InputDecoration(
                  hintText: "Search item or barcode...",
                  hintStyle: GoogleFonts.poppins(color: Colors.grey),
                  border: InputBorder.none,
                ),
              )
            : Text("Inventory", style: GoogleFonts.poppins(color: _textColor, fontWeight: FontWeight.bold, fontSize: 24)),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search, color: _textColor),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear(); // Clear search when closed
                }
              });
            },
          ),
          // 4. Filter Menu
          PopupMenuButton<String>(
            icon: Icon(Icons.sort, color: _textColor),
            onSelected: (value) => setState(() => _sortBy = value),
            itemBuilder: (ctx) => [
              PopupMenuItem(value: 'name', child: Text("Name (A-Z)")),
              PopupMenuItem(value: 'price_high', child: Text("Highest Price")),
              PopupMenuItem(value: 'stock_low', child: Text("Lowest Stock")),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Action Buttons
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.add,
                    label: "Add New",
                    bgColor: Theme.of(context).brightness == Brightness.light ? const Color(0xFF1A1A1A) : const Color(0xFF333333),
                    textColor: Colors.white,
                    iconColor: _primaryOrange,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AddProductScreen())),
                  ),
                ),
                SizedBox(width: 15),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.qr_code_scanner,
                    label: "Quick Scan",
                    bgColor: _cardColor,
                    textColor: _textColor,
                    iconColor: _textColor,
                    onTap: _handleQuickEntry,
                  ),
                ),
              ],
            ),
          ),

          // Product List
          Expanded(
            child: displayList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 60, color: Colors.grey.shade400),
                      SizedBox(height: 10),
                      Text("No items found", style: GoogleFonts.poppins(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  itemCount: displayList.length,
                  separatorBuilder: (ctx, i) => SizedBox(height: 15),
                  itemBuilder: (ctx, i) {
                    final product = displayList[i];
                    final isOutOfStock = product.stockQty == 0;
                    final isLowStock = product.stockQty < 5 && !isOutOfStock;

                    return GestureDetector(
                      onTap: () => _showProductDetailsModal(product),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _cardColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: Container(
                            width: 60, height: 60,
                            decoration: BoxDecoration(
                              color: _containerColor,
                              borderRadius: BorderRadius.circular(15),
                              image: product.imagePath != null
                                ? DecorationImage(image: FileImage(File(product.imagePath!)), fit: BoxFit.cover)
                                : null
                            ),
                            child: product.imagePath == null 
                              ? Icon(Icons.inventory_2_outlined, color: Colors.grey.shade400) 
                              : null,
                          ),
                          title: Text(
                            product.name, 
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16, color: _textColor)
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text("KES ${product.sellPrice.toStringAsFixed(0)}", style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 13)),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isOutOfStock 
                                    ? Colors.red.withOpacity(0.1) 
                                    : (isLowStock ? _primaryOrange.withOpacity(0.1) : Colors.green.withOpacity(0.1)),
                                  borderRadius: BorderRadius.circular(8)
                                ),
                                child: Text(
                                  isOutOfStock ? "Out of Stock" : "${product.stockQty} ${product.unit} in stock",
                                  style: GoogleFonts.poppins(
                                    fontSize: 11, 
                                    fontWeight: FontWeight.w600,
                                    color: isOutOfStock ? Colors.red : (isLowStock ? _primaryOrange : Colors.green)
                                  ),
                                ),
                              )
                            ],
                          ),
                          trailing: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context, 
                                MaterialPageRoute(builder: (context) => AddProductScreen(productToEdit: product))
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: _containerColor, shape: BoxShape.circle),
                              child: Icon(Icons.edit_outlined, color: _textColor, size: 18),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
          )
        ],
      ),
    );
  }

  void _showProductDetailsModal(Product product) {
    final inventory = Provider.of<InventoryProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: _surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: FutureBuilder<Map<String, dynamic>>(
            future: inventory.getProductProfitability(product),
            builder: (context, snapshot) {
              final profitData = snapshot.data ?? {
                'unit_profit': product.sellPrice - product.buyPrice,
                'margin_percent': product.sellPrice > 0 ? ((product.sellPrice - product.buyPrice) / product.sellPrice) * 100 : 0.0,
                'monthly_sold': 0.0,
                'monthly_profit': 0.0,
                'recommendation': 'Analyzing profitability...',
              };

              final unitProfit = (profitData['unit_profit'] as num?)?.toDouble() ?? 0.0;
              final margin = (profitData['margin_percent'] as num?)?.toDouble() ?? 0.0;
              final monthlySold = (profitData['monthly_sold'] as num?)?.toDouble() ?? 0.0;
              final monthlyProfit = (profitData['monthly_profit'] as num?)?.toDouble() ?? 0.0;
              final recommendation = profitData['recommendation'] as String? ?? "";

              return ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(22),
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Title & Barcode Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: _textColor),
                            ),
                            Text(
                              "Barcode: ${product.barcode} • Unit: ${product.unit}",
                              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: margin >= 20 ? Colors.green.withOpacity(0.12) : Colors.orange.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "${margin.toStringAsFixed(1)}% Margin",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: margin >= 20 ? Colors.green : Colors.orange,
                          ),
                        ),
                      )
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Profitability Breakdown Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: _cardColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.analytics_outlined, color: Colors.blue, size: 18),
                            const SizedBox(width: 6),
                            Text("PROFITABILITY & PRICING", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.1)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildInfoCol("Buying Price", "KES ${product.buyPrice.toStringAsFixed(0)}"),
                            _buildInfoCol("Selling Price", "KES ${product.sellPrice.toStringAsFixed(0)}"),
                            _buildInfoCol("Unit Profit", "KES ${unitProfit.toStringAsFixed(0)}", isHighlight: true),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Divider(height: 1),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildInfoCol("Sold This Month", "${monthlySold.toStringAsFixed(0)} ${product.unit}"),
                            _buildInfoCol("Monthly Profit", "KES ${monthlyProfit.toStringAsFixed(0)}", isHighlight: true),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Recommendation Banner
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _primaryOrange.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _primaryOrange.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lightbulb_outline, color: _primaryOrange, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            recommendation,
                            style: GoogleFonts.poppins(fontSize: 12, color: _textColor, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // Stock Movements Section
                  Row(
                    children: [
                      const Icon(Icons.history_outlined, size: 18, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text("Stock Movement Audit Trail", style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: _textColor)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  FutureBuilder(
                    future: inventory.getStockMovements(product.id!),
                    builder: (context, movSnapshot) {
                      if (!movSnapshot.hasData) {
                        return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
                      }

                      final movements = movSnapshot.data!;
                      if (movements.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(16)),
                          child: Center(
                            child: Text("No stock movements recorded yet.", style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
                          ),
                        );
                      }

                      return Column(
                        children: movements.map((m) {
                          final isAdd = m.changeQty > 0;
                          final isSale = m.type == 'SALE';
                          final timeStr = "${m.dateTime.day}/${m.dateTime.month} ${m.dateTime.hour}:${m.dateTime.minute.toString().padLeft(2, '0')}";

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: _cardColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: _containerColor),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: isSale ? Colors.orange.withOpacity(0.12) : (isAdd ? Colors.green.withOpacity(0.12) : Colors.blue.withOpacity(0.12)),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isSale ? Icons.arrow_downward : (isAdd ? Icons.arrow_upward : Icons.tune),
                                    size: 14,
                                    color: isSale ? Colors.orange : (isAdd ? Colors.green : Colors.blue),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "${m.type} (${m.changeQty > 0 ? '+' : ''}${m.changeQty} ${product.unit})",
                                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12, color: _textColor),
                                      ),
                                      Text(
                                        "${m.previousQty} -> ${m.newQty} • ${m.reason ?? ''}",
                                        style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  timeStr,
                                  style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),

                  const SizedBox(height: 25),

                  // Bottom Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: Colors.redAccent),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                          label: Text("Delete Item", style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await inventory.deleteProduct(product.id!);
                            FeedbackDialog.show(context, title: "Deleted", message: "${product.name} removed from inventory.", isSuccess: true);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryOrange,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 18),
                          label: Text("Edit Details", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => AddProductScreen(productToEdit: product)),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCol(String label, String value, {bool isHighlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isHighlight ? _primaryOrange : _textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color bgColor,
    required Color textColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            if (bgColor == Colors.white || bgColor == _cardColor)
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 4))
          ]
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 20),
            SizedBox(width: 10),
            Text(label, style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}