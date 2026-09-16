import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:duka_manager/providers/shop_provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:google_fonts/google_fonts.dart';
import '../models/product.dart';
import '../providers/inventory_provider.dart';
import '../widgets/simple_scanner_page.dart';
import '../widgets/feedback_dialog.dart';

class AddProductScreen extends StatefulWidget {
  final String? initialBarcode;
  final Product? productToEdit;

  const AddProductScreen({super.key, this.initialBarcode, this.productToEdit});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _buyPriceController = TextEditingController();
  final _sellPriceController = TextEditingController();
  final _qtyController = TextEditingController();
  File? _selectedImage;
  String _selectedUnit = 'Pcs';
  final List<String> _units = ['Pcs', 'Kg', 'Litre', 'Bunch', 'Packet', 'Dozen'];

  // 🎨 THEME COLORS (Dynamic Getters)
  Color get _primaryOrange => const Color(0xFFFF6B00);
  Color get _containerColor => Theme.of(context).brightness == Brightness.light ? const Color(0xFFF5F6F8) : const Color(0xFF121212);
  Color get _cardColor => Theme.of(context).brightness == Brightness.light ? Colors.white : const Color(0xFF1E1E1E);
  Color get _textColor => Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF1A1A1A);

  @override
  void initState() {
    super.initState();
    if (widget.productToEdit != null) {
      final p = widget.productToEdit!;
      _nameController.text = p.name;
      _barcodeController.text = p.barcode;
      _buyPriceController.text = p.buyPrice.toString();
      _sellPriceController.text = p.sellPrice.toString();
      _qtyController.text = p.stockQty.toString();
      _selectedUnit = p.unit;
      if (p.imagePath != null) {
        _selectedImage = File(p.imagePath!);
      }
    } else if (widget.initialBarcode != null) {
      _barcodeController.text = widget.initialBarcode!;
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? imageFile = await picker.pickImage(
        source: source,
        maxWidth: 600,
        imageQuality: 85,
      );

      if (imageFile == null) return;

      final appDir = await getApplicationDocumentsDirectory();
      final fileName = path.basename(imageFile.path);
      final savedImage = await File(imageFile.path).copy('${appDir.path}/$fileName');

      setState(() {
        _selectedImage = savedImage;
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint("Image Pick Error: $e");
    }
  }

  void _generateManualCode() {
    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String shortCode = timestamp.substring(timestamp.length - 4);
    setState(() {
      _barcodeController.text = "MAN-$shortCode";
    });
  }

  void _showImageSourceOptions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text("Select Image Source",
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, fontSize: 16, color: _textColor)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSourceButton(
                    icon: Icons.camera_alt,
                    label: "Camera",
                    onTap: () => _pickImage(ImageSource.camera)),
                _buildSourceButton(
                    icon: Icons.photo_library,
                    label: "Gallery",
                    onTap: () => _pickImage(ImageSource.gallery)),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: _primaryOrange.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _primaryOrange, size: 30),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 14, color: _textColor, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Future<void> _scanBarcode() async {
    final scannedCode = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SimpleScannerPage()),
    );
    
    if (!mounted) return;

    if (scannedCode != null) {
      setState(() {
        _barcodeController.text = scannedCode;
      });
    }
  }

  void _saveProduct() async {
    if (_formKey.currentState!.validate()) {
      String finalBarcode = _barcodeController.text.trim();

      if (finalBarcode.isEmpty) {
        _generateManualCode();
        finalBarcode = _barcodeController.text;
      }

      final product = Product(
        id: widget.productToEdit?.id,
        name: _nameController.text,
        barcode: finalBarcode,
        buyPrice: double.parse(_buyPriceController.text),
        sellPrice: double.parse(_sellPriceController.text),
        stockQty: double.parse(_qtyController.text),
        unit: _selectedUnit,
        imagePath: _selectedImage?.path,
      );

      final provider = Provider.of<InventoryProvider>(context, listen: false);
      final shop = Provider.of<ShopProvider>(context, listen: false);
      if (widget.productToEdit != null) {
        await provider.updateProduct(product, isPro: shop.isProActive);
      } else {
        await provider.addProduct(product, isPro: shop.isProActive);
      }

      if (mounted) {
        Navigator.pop(context, product);
        FeedbackDialog.show(context,
            title: "Success", message: "Product saved successfully", isSuccess: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditMode = widget.productToEdit != null;

    return Scaffold(
      backgroundColor: _containerColor,
      appBar: AppBar(
        backgroundColor: _containerColor,
        elevation: 0,
        iconTheme: IconThemeData(color: _textColor),
        title: Text(isEditMode ? 'Edit Product' : 'New Product',
            style: GoogleFonts.poppins(color: _textColor, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Image Picker
              Center(
                child: GestureDetector(
                  onTap: _showImageSourceOptions,
                  child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                          color: _cardColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(
                                    alpha: Theme.of(context).brightness == Brightness.dark ? 0.25 : 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 5))
                          ],
                          border: Border.all(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.grey.shade200),
                          image: _selectedImage != null
                              ? DecorationImage(
                                  image: FileImage(_selectedImage!), fit: BoxFit.cover)
                              : null),
                      child: _selectedImage == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt_outlined,
                                    color: _primaryOrange, size: 30),
                                const SizedBox(height: 5),
                                Text("Add Photo",
                                    style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? Colors.white54
                                            : Colors.grey)),
                              ],
                            )
                          : null),
                ),
              ),
              const SizedBox(height: 30),

              // Barcode Field with Side-by-Side Icons
              _buildModernField(
                _barcodeController,
                'Barcode / Product ID',
                icon: Icons.qr_code,
                readOnly: isEditMode,
                // 🚀 FIXED: We pass the Row directly to suffixWidget
                suffixWidget: isEditMode
                    ? null
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.qr_code_scanner, color: _primaryOrange),
                            onPressed: _scanBarcode,
                          ),
                          IconButton(
                            icon: const Icon(Icons.auto_fix_high, color: Colors.blue),
                            onPressed: _generateManualCode,
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 15),

              // Unit Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.grey.shade200,
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(
                            alpha: Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedUnit,
                    dropdownColor: _cardColor,
                    style: GoogleFonts.poppins(color: _textColor, fontWeight: FontWeight.w500),
                    icon: Icon(Icons.arrow_drop_down,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white54
                            : Colors.grey),
                    decoration: InputDecoration(
                      labelText: "Unit of Measure",
                      labelStyle: GoogleFonts.poppins(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white38
                              : Colors.grey),
                      prefixIcon: Icon(Icons.straighten,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white38
                              : Colors.grey),
                      border: InputBorder.none,
                    ),
                    items: _units.map((String unit) {
                      return DropdownMenuItem(
                          value: unit,
                          child: Text(unit,
                              style: GoogleFonts.poppins(color: _textColor)));
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedUnit = val!),
                  ),
                ),
              ),
              const SizedBox(height: 15),

              _buildModernField(_nameController, 'Product Name', icon: Icons.tag),
              const SizedBox(height: 15),

              Row(
                children: [
                  Expanded(
                      child: _buildModernField(_buyPriceController, 'Buy Price',
                          icon: Icons.attach_money, isNumber: true)),
                  const SizedBox(width: 15),
                  Expanded(
                      child: _buildModernField(_sellPriceController, 'Sell Price',
                          icon: Icons.price_check, isNumber: true)),
                ],
              ),
              const SizedBox(height: 15),

              _buildModernField(_qtyController, 'Stock Quantity',
                  icon: Icons.inventory_2, isNumber: true),

              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 3,
                    shadowColor: _primaryOrange.withValues(alpha: 0.4),
                  ),
                  onPressed: _saveProduct,
                  child: Text(
                    isEditMode ? 'UPDATE PRODUCT' : 'SAVE PRODUCT',
                    style: GoogleFonts.poppins(
                        fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🚀 Helper function for modern styled text fields
  Widget _buildModernField(
    TextEditingController controller,
    String label, {
    IconData? icon,
    bool isNumber = false,
    Widget? suffixWidget, // Changed from IconData to Widget
    bool readOnly = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: readOnly
            ? (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade100)
            : _cardColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: isNumber
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w500,
          color: readOnly ? (isDark ? Colors.white54 : Colors.grey.shade600) : _textColor,
        ),
        validator: (val) => val!.isEmpty ? 'Required' : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(
            color: isDark ? Colors.white38 : Colors.grey,
          ),
          prefixIcon: icon != null
              ? Icon(icon, color: isDark ? Colors.white38 : Colors.grey.shade400)
              : null,
          suffixIcon: suffixWidget, // Now handles our Row widget
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }
}