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

                    return Container(
                      decoration: BoxDecoration(
                        color: _cardColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 4))
                        ],
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.all(12),
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
                            ? Icon(Icons.shopping_bag_outlined, color: Colors.grey.shade400) 
                            : null,
                        ),
                        title: Text(
                          product.name, 
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16, color: _textColor)
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 4),
                            Text("KES ${product.sellPrice.toStringAsFixed(0)}", style: GoogleFonts.poppins(color: Colors.grey.shade600, fontSize: 13)),
                            SizedBox(height: 6),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isOutOfStock 
                                  ? Colors.red.withOpacity(0.1) 
                                  : (isLowStock ? _primaryOrange.withOpacity(0.1) : Colors.green.withOpacity(0.1)),
                                borderRadius: BorderRadius.circular(8)
                              ),
                              child: Text(
                                isOutOfStock ? "Out of Stock" : "${product.stockQty} in stock",
                                style: GoogleFonts.poppins(
                                  fontSize: 11, 
                                  fontWeight: FontWeight.w600,
                                  color: isOutOfStock ? Colors.red : (isLowStock ? _primaryOrange : Colors.green)
                                ),
                              ),
                            )
                          ],
                        ),
                        // 5. Edit Button Logic
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
                    );
                  },
                ),
          )
        ],
      ),
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