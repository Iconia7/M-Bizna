import 'dart:io';
import 'package:csv/csv.dart';
import 'package:duka_manager/db/database_helper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class BackupService {
  Future<void> createAndShareBackup() async {
    final db = await DatabaseHelper.instance.database;
    
    // 1. Fetch Data
    final List<Map<String, dynamic>> products = await db.query('products');
    final List<Map<String, dynamic>> sales = await db.query('sales');
    final List<Map<String, dynamic>> customers = await db.query('customers');
    final List<Map<String, dynamic>> expenses = await db.query('expenses');
    final List<Map<String, dynamic>> suppliers = await db.query('suppliers');

    // 2. Convert to CSV Lists
    List<List<dynamic>> productCsv = [
      ['ID', 'Name', 'Barcode', 'Buy Price', 'Sell Price', 'Stock'] // Headers
    ];
    for (var p in products) {
      productCsv.add([p['id'], p['name'], p['barcode'], p['buy_price'], p['sell_price'], p['stock_qty']]);
    }

    List<List<dynamic>> salesCsv = [
      ['ID', 'Product ID', 'Customer ID', 'Qty', 'Total', 'Profit', 'Payment Method', 'Date'] // Headers
    ];
    for (var s in sales) {
      salesCsv.add([s['id'], s['product_id'], s['customer_id'], s['quantity'], s['total_price'], s['profit'], s['payment_method'], s['date_time']]);
    }

    List<List<dynamic>> customerCsv = [
      ['ID', 'Name', 'Phone', 'Current Debt', 'Credit Limit']
    ];
    for (var c in customers) {
      customerCsv.add([c['id'], c['name'], c['phone'], c['current_debt'], c['credit_limit']]);
    }

    List<List<dynamic>> expenseCsv = [
      ['ID', 'Description', 'Amount', 'Category', 'Date']
    ];
    for (var e in expenses) {
      expenseCsv.add([e['id'], e['description'], e['amount'], e['category'], e['date_time']]);
    }

    List<List<dynamic>> supplierCsv = [
      ['ID', 'Name', 'Phone', 'Company', 'Payment Details', 'Notes']
    ];
    for (var sup in suppliers) {
      supplierCsv.add([sup['id'], sup['name'], sup['phone'], sup['company'], sup['payment_details'], sup['notes']]);
    }

    // 3. Encode to String
    const converter = ListToCsvConverter();
    String productString = converter.convert(productCsv);
    String salesString = converter.convert(salesCsv);
    String customerString = converter.convert(customerCsv);
    String expenseString = converter.convert(expenseCsv);
    String supplierString = converter.convert(supplierCsv);

    // 4. Save Files
    final directory = await getApplicationDocumentsDirectory();
    final path = directory.path;
    
    final productFile = File('$path/products_backup.csv');
    await productFile.writeAsString(productString);

    final salesFile = File('$path/sales_backup.csv');
    await salesFile.writeAsString(salesString);

    final customerFile = File('$path/customers_backup.csv');
    await customerFile.writeAsString(customerString);

    final expenseFile = File('$path/expenses_backup.csv');
    await expenseFile.writeAsString(expenseString);

    final supplierFile = File('$path/suppliers_backup.csv');
    await supplierFile.writeAsString(supplierString);

    // 5. Share Files
    await Share.shareXFiles(
      [
        XFile(productFile.path),
        XFile(salesFile.path),
        XFile(customerFile.path),
        XFile(expenseFile.path),
        XFile(supplierFile.path),
      ],
      text: 'M-Bizna Full Backup - ${DateTime.now().toString().substring(0, 16)}'
    );
  }
}