import 'package:duka_manager/db/database_helper.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/customer.dart';
import '../models/customer_ledger_entry.dart';

class CustomerProvider with ChangeNotifier {
  List<Customer> _customers = [];

  List<Customer> get customers => [..._customers];

  Future<void> loadCustomers() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query('customers', orderBy: 'current_debt DESC');
    _customers = result.map((json) => Customer.fromMap(json)).toList();
    notifyListeners();
  }

  Future<void> addCustomer(Customer customer) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('customers', customer.toMap());
    await loadCustomers();
  }

  // Record a credit sale (Increase Debt & Log to Ledger)
  Future<bool> recordCreditSale(int customerId, double amount, {String? note}) async {
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
    final now = DateTime.now().toIso8601String();
    
    await db.update(
      'customers',
      {'current_debt': newDebt},
      where: 'id = ?',
      whereArgs: [customerId],
    );

    // 3. Log to Customer Ledger
    await db.insert('customer_ledger', {
      'customer_id': customerId,
      'type': 'CREDIT_SALE',
      'amount': amount,
      'balance_after': newDebt,
      'note': note ?? 'Credit Sale',
      'date_time': now,
    });

    await loadCustomers();
    return true;
  }

  // Record a payment (Decrease Debt & Log to Ledger)
  Future<void> payDebt(int customerId, double amount, {String? note}) async {
    final customer = _customers.firstWhere((c) => c.id == customerId);
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toIso8601String();
    
    double newDebt = customer.currentDebt - amount;
    if (newDebt < 0) newDebt = 0;

    await db.update(
      'customers',
      {'current_debt': newDebt},
      where: 'id = ?',
      whereArgs: [customerId],
    );

    // Log to Customer Ledger
    await db.insert('customer_ledger', {
      'customer_id': customerId,
      'type': 'PAYMENT',
      'amount': amount,
      'balance_after': newDebt,
      'note': note ?? 'Debt Repayment',
      'date_time': now,
    });

    await loadCustomers();
  }

  // Fetch Customer Credit & Payment Ledger
  Future<List<CustomerLedgerEntry>> getCustomerLedger(int customerId) async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.query(
      'customer_ledger',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'date_time DESC',
      limit: 30,
    );

    return result.map((json) => CustomerLedgerEntry.fromMap(json)).toList();
  }

  // Format phone to international format (254...)
  String _formatPhone(String rawPhone) {
    String phone = rawPhone.trim();
    if (phone.startsWith('0')) {
      return "254${phone.substring(1)}";
    } else if (phone.startsWith('+254')) {
      return phone.substring(1);
    }
    return phone;
  }

  // WhatsApp Quick Reminder
  Future<void> sendWhatsAppReminder(Customer customer, String shopName) async {
    final phone = _formatPhone(customer.phone);
    final message = "Hello ${customer.name}, this is a polite reminder from $shopName. Your current outstanding balance is KES ${customer.currentDebt.toStringAsFixed(0)}. Please settle via M-Pesa. Thank you for your business!";
    final url = Uri.parse("https://wa.me/$phone?text=${Uri.encodeComponent(message)}");

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      debugPrint("Could not launch WhatsApp");
    }
  }

  // Detailed Customer Statement with Recent History
  Future<void> sendWhatsAppStatement(
    Customer customer, 
    String shopName, 
    Map<String, dynamic> settings
  ) async {
    final phone = _formatPhone(customer.phone);
    final dateStr = DateFormat('dd MMM yyyy, h:mm a').format(DateTime.now());

    String paymentInfo = "";
    final mode = settings['mpesa_mode'] ?? 'Manual';
    if (mode == 'Automated') {
      final channelType = settings['mpesa_channel_type'] ?? 'Paybill';
      final shortcode = settings['mpesa_shortcode'] ?? '';
      final account = settings['mpesa_account'] ?? '';
      if (channelType == 'Paybill') {
        paymentInfo = "Paybill: $shortcode\nAccount: ${account.isNotEmpty ? account : customer.name}";
      } else {
        paymentInfo = "Till Number: $shortcode";
      }
    } else {
      final mpesaNum = settings['mpesa_number'] ?? '';
      paymentInfo = "Send Money (M-Pesa): $mpesaNum";
    }

    // Fetch recent 3 ledger entries for itemized statement
    final ledger = await getCustomerLedger(customer.id!);

    final buffer = StringBuffer();
    buffer.writeln("==============================");
    buffer.writeln("CUSTOMER ACCOUNT STATEMENT");
    buffer.writeln("==============================");
    buffer.writeln("Store: $shopName");
    buffer.writeln("Customer: ${customer.name}");
    buffer.writeln("Date: $dateStr");
    buffer.writeln("------------------------------");
    buffer.writeln("Total Outstanding: KES ${customer.currentDebt.toStringAsFixed(0)}");
    buffer.writeln("Credit Limit: KES ${customer.creditLimit.toStringAsFixed(0)}");
    
    if (ledger.isNotEmpty) {
      buffer.writeln("------------------------------");
      buffer.writeln("Recent Activity:");
      for (var entry in ledger.take(3)) {
        final entryDate = DateFormat('dd MMM').format(entry.dateTime);
        final prefix = entry.type == 'CREDIT_SALE' ? '+KES' : '-KES';
        final desc = entry.type == 'CREDIT_SALE' ? 'Credit Purchase' : 'Payment Received';
        buffer.writeln("• $entryDate: $desc ($prefix ${entry.amount.toStringAsFixed(0)})");
      }
    }

    buffer.writeln("------------------------------");
    buffer.writeln("Payment Details:");
    buffer.writeln(paymentInfo);
    buffer.writeln("------------------------------");
    buffer.writeln("Please clear your outstanding balance at your earliest convenience.");
    buffer.writeln("Thank you for your valued custom.");
    buffer.writeln("==============================");
    buffer.writeln("Generated via M-Bizna");

    final url = Uri.parse("https://wa.me/$phone?text=${Uri.encodeComponent(buffer.toString())}");

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      debugPrint("Could not launch WhatsApp");
    }
  }
}