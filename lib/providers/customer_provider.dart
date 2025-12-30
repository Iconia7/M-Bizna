import 'package:duka_manager/db/database_helper.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/customer.dart';

class CustomerProvider with ChangeNotifier {
  List<Customer> _customers = [];

  List<Customer> get customers => [..._customers];

  Future<void> loadCustomers() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query('customers', orderBy: 'current_debt DESC'); // Highest debt first
    _customers = result.map((json) => Customer.fromMap(json)).toList();
    notifyListeners();
  }

  Future<void> addCustomer(Customer customer) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('customers', customer.toMap());
    await loadCustomers();
  }

  // Record a credit sale (Increase Debt)
  Future<bool> recordCreditSale(int customerId, double amount) async {
    final index = _customers.indexWhere((c) => c.id == customerId);
    if (index == -1) return false;

    final customer = _customers[index];
    
    // 1. Check Credit Limit
    if ((customer.currentDebt + amount) > customer.creditLimit) {
      return false; // Sale blocked!
    }

    // 2. Update DB
    final db = await DatabaseHelper.instance.database;
    final newDebt = customer.currentDebt + amount;
    
    await db.update(
      'customers',
      {'current_debt': newDebt},
      where: 'id = ?',
      whereArgs: [customerId],
    );

    await loadCustomers();
    return true;
  }

  // Record a payment (Decrease Debt)
  Future<void> payDebt(int customerId, double amount) async {
    final customer = _customers.firstWhere((c) => c.id == customerId);
    final db = await DatabaseHelper.instance.database;
    
    double newDebt = customer.currentDebt - amount;
    if (newDebt < 0) newDebt = 0;

    await db.update(
      'customers',
      {'current_debt': newDebt},
      where: 'id = ?',
      whereArgs: [customerId],
    );
    await loadCustomers();
  }

  // 🚀 WhatsApp Reminder Logic
  Future<void> sendWhatsAppReminder(Customer customer) async {
    // Format: 0712345678 -> 254712345678
    String phone = customer.phone;
    if (phone.startsWith('0')) {
      phone = "254${phone.substring(1)}";
    }

    final message = "Hello ${customer.name}, a polite reminder from M-Bizna Shop. Your outstanding balance is KES ${customer.currentDebt}. Please pay via M-Pesa. Thank you!";
    final url = Uri.parse("https://wa.me/$phone?text=${Uri.encodeComponent(message)}");

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      debugPrint("Could not launch WhatsApp");
    }
  }
}