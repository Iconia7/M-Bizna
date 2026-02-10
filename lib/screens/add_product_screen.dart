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

  AddProductScreen({this.initialBarcode, this.productToEdit});

  @override
  _AddProductScreenState createState() => _AddProductScreenState();
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
  Color get _surfaceColor => Theme.of(context).colorScheme.surface;
  Color get _containerColor => Theme.of(context).brightness == Brightness.light ? const Color(0xFFF5F6F8) : Colors.white.withOpacity(0.05);
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
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Select Image Source",
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
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
              color: _primaryOrange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _primaryOrange, size: 30),
          ),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.poppins(fontSize: 14)),
        ],
      ),
    );
  }

  Future<void> _scanBarcode() async {
    final scannedCode = await Navigator.push(
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
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: Offset(0, 5))
                          ],
                          border: Border.all(color: Colors.grey.shade200),
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
                                SizedBox(height: 5),
                                Text("Add Photo",
                                    style: GoogleFonts.poppins(
                                        fontSize: 12, color: Colors.grey)),
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.grey.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButtonFormField<String>(
                    value: _selectedUnit,
                    decoration: InputDecoration(
                      labelText: "Unit of Measure",
                      labelStyle: GoogleFonts.poppins(color: Colors.grey),
                      prefixIcon: const Icon(Icons.straighten, color: Colors.grey),
                      border: InputBorder.none,
                    ),
                    items: _units.map((String unit) {
                      return DropdownMenuItem(
                          value: unit, child: Text(unit, style: GoogleFonts.poppins()));
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
                    backgroundColor: _textColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 5,
                    shadowColor: _textColor.withOpacity(0.3),
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

  // 🚀 FIXED: Helper function now accepts a Widget? for the suffix
  Widget _buildModernField(
    TextEditingController controller,
    String label, {
    IconData? icon,
    bool isNumber = false,
    Widget? suffixWidget, // Changed from IconData to Widget
    bool readOnly = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: readOnly ? Colors.grey.shade200 : Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
              color: Colors.grey.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: isNumber
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: _textColor),
        validator: (val) => val!.isEmpty ? 'Required' : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.poppins(color: Colors.grey),
          prefixIcon: icon != null ? Icon(icon, color: Colors.grey.shade400) : null,
          suffixIcon: suffixWidget, // Now handles our Row widget
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }
}