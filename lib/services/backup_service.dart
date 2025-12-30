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

    // 2. Convert to CSV Lists
    List<List<dynamic>> productCsv = [
      ['ID', 'Name', 'Barcode', 'Buy Price', 'Sell Price', 'Stock'] // Headers
    ];
    for (var p in products) {
      productCsv.add([p['id'], p['name'], p['barcode'], p['buy_price'], p['sell_price'], p['stock_qty']]);
    }

    List<List<dynamic>> salesCsv = [
      ['ID', 'Product ID', 'Qty', 'Total', 'Profit', 'Date'] // Headers
    ];
    for (var s in sales) {
      salesCsv.add([s['id'], s['product_id'], s['quantity'], s['total_price'], s['profit'], s['date_time']]);
    }

    // 3. Encode to String
    String productString = const ListToCsvConverter().convert(productCsv);
    String salesString = const ListToCsvConverter().convert(salesCsv);

    // 4. Save Files
    final directory = await getApplicationDocumentsDirectory();
    final path = directory.path;
    
    final productFile = File('$path/products_backup.csv');
    await productFile.writeAsString(productString);

    final salesFile = File('$path/sales_backup.csv');
    await salesFile.writeAsString(salesString);

    // 5. Share Files
    await Share.shareXFiles(
      [XFile(productFile.path), XFile(salesFile.path)],
      text: 'M-Bizna Backup - ${DateTime.now()}'
    );
  }
}