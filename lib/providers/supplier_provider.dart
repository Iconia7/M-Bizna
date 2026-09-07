import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../db/database_helper.dart';
import '../models/supplier.dart';

class SupplierProvider with ChangeNotifier {
  List<Supplier> _suppliers = [];

  List<Supplier> get suppliers => [..._suppliers];

  Future<void> loadSuppliers() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query('suppliers', orderBy: 'name ASC');
    _suppliers = result.map((json) => Supplier.fromMap(json)).toList();
    notifyListeners();
  }

  Future<void> addSupplier(Supplier supplier) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('suppliers', supplier.toMap());
    await loadSuppliers();
  }

  Future<void> updateSupplier(Supplier supplier) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'suppliers',
      supplier.toMap(),
      where: 'id = ?',
      whereArgs: [supplier.id],
    );
    await loadSuppliers();
  }

  Future<void> deleteSupplier(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('suppliers', where: 'id = ?', whereArgs: [id]);
    await loadSuppliers();
  }

  // Format phone to international format
  String _formatPhone(String rawPhone) {
    String phone = rawPhone.trim();
    if (phone.startsWith('0')) {
      return "254${phone.substring(1)}";
    } else if (phone.startsWith('+254')) {
      return phone.substring(1);
    }
    return phone;
  }

  // Generate & Send WhatsApp Purchase Order
  Future<void> sendPurchaseOrder(
    Supplier supplier, 
    List<Map<String, dynamic>> itemsToOrder, 
    String shopName
  ) async {
    final phone = _formatPhone(supplier.phone);
    final dateStr = DateFormat('dd MMM yyyy').format(DateTime.now());

    final buffer = StringBuffer();
    buffer.writeln("==============================");
    buffer.writeln("PURCHASE ORDER / RESTOCK REQUEST");
    buffer.writeln("==============================");
    buffer.writeln("To: ${supplier.name} ${supplier.company != null && supplier.company!.isNotEmpty ? '(${supplier.company})' : ''}");
    buffer.writeln("From Store: $shopName");
    buffer.writeln("Date: $dateStr");
    buffer.writeln("------------------------------");
    buffer.writeln("ITEMS REQUESTED:");

    for (var item in itemsToOrder) {
      final name = item['name'];
      final qty = item['qty'];
      final unit = item['unit'] ?? 'Pcs';
      buffer.writeln("• $name: $qty $unit");
    }

    buffer.writeln("------------------------------");
    if (supplier.paymentDetails != null && supplier.paymentDetails!.isNotEmpty) {
      buffer.writeln("Payment Method: ${supplier.paymentDetails}");
      buffer.writeln("------------------------------");
    }
    buffer.writeln("Please confirm receipt and expected delivery time.");
    buffer.writeln("Thank you!");
    buffer.writeln("==============================");
    buffer.writeln("Generated via M-Bizna");

    final url = Uri.parse("https://wa.me/$phone?text=${Uri.encodeComponent(buffer.toString())}");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
