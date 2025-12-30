// lib/services/printer_service.dart

import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/services.dart';

class PrinterService {
  BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;

  Future<bool> get isConnected async => (await bluetooth.isConnected) ?? false;

  Future<List<BluetoothDevice>> getBondedDevices() async {
    try {
      return await bluetooth.getBondedDevices();
    } on PlatformException {
      return [];
    }
  }

  Future<bool> connect(BluetoothDevice device) async {
    try {
      if (await isConnected) await bluetooth.disconnect();
      await bluetooth.connect(device);
      return true;
    } catch (e) {
      return false;
    }
  }

  // 🖨️ UPDATED STYLISH PRINTING LOGIC
  Future<void> printReceipt({
    required String shopName,
    required List<Map<String, dynamic>> items,
    required double total,
    required String date,
  }) async {
    if (!(await isConnected)) return;

    // 1. Header (Bold & Large)
    bluetooth.printNewLine();
    bluetooth.printCustom(shopName.toUpperCase(), 3, 1); // Large centered
    bluetooth.printCustom("OFFICIAL RECEIPT", 1, 1);
    bluetooth.printCustom(date, 0, 1);
    bluetooth.printNewLine();

    // 2. Stylish Divider
    bluetooth.printCustom("================================", 1, 1);

    // 3. Table Header
    bluetooth.printLeftRight("QTY  ITEM", "PRICE", 1);
    bluetooth.printCustom("--------------------------------", 1, 1);

    // 4. Dynamic Items List
    for (var item in items) {
      String name = item['name'];
      int qty = item['qty'];
      double price = item['price']; 
      
      // Handle long names by wrapping or truncating
      String displayName = name.length > 20 ? name.substring(0, 18) + ".." : name;
      
      // Format: "2x  Milk"           "KES 100"
      bluetooth.printLeftRight("${qty}x  $displayName", price.toStringAsFixed(0), 0);
    }

    // 5. Summary Section
    bluetooth.printCustom("--------------------------------", 1, 1);
    bluetooth.printNewLine();
    bluetooth.printLeftRight("TOTAL AMOUNT", "KES ${total.toStringAsFixed(2)}", 2); // Bold 
    bluetooth.printNewLine();
    bluetooth.printCustom("================================", 1, 1);

    // 6. Footer (Social/Trust)
    bluetooth.printCustom("Goods once sold are not returnable", 0, 1);
    bluetooth.printCustom("Thank you for your business!", 1, 1);
    bluetooth.printNewLine();
    bluetooth.printCustom("Software by M-Bizna", 0, 1);
    
    // 7. Space for tearing
    bluetooth.printNewLine();
    bluetooth.printNewLine();
    bluetooth.printNewLine();
    bluetooth.paperCut(); 
  }
}