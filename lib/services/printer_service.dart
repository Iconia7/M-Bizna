// lib/services/printer_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PrinterConnectionType {
  bluetooth,
  wifi,
}

/// Helper to generate ESC/POS command byte sequences for standard thermal receipt printers
class EscPosBuilder {
  final List<int> _bytes = [];

  List<int> get bytes => _bytes;

  void reset() {
    _bytes.addAll([0x1B, 0x40]); // ESC @ (Initialize)
  }

  void setAlign(int align) {
    // 0: Left, 1: Center, 2: Right
    _bytes.addAll([0x1B, 0x61, align]);
  }

  void setBold(bool bold) {
    _bytes.addAll([0x1B, 0x45, bold ? 1 : 0]);
  }

  void setTextSize(int widthScale, int heightScale) {
    // GS ! n (0: normal, 1: double height, 2: large, etc.)
    final int n = ((widthScale & 0x07) << 4) | (heightScale & 0x07);
    _bytes.addAll([0x1D, 0x21, n]);
  }

  void text(
    String text, {
    bool bold = false,
    int align = 0,
    int size = 0,
  }) {
    setAlign(align);
    setBold(bold);
    if (size == 0) {
      setTextSize(0, 0); // Normal
    } else if (size == 1) {
      setTextSize(0, 1); // Double height
    } else if (size == 2) {
      setTextSize(1, 1); // Double width & height
    } else if (size == 3) {
      setTextSize(2, 2); // Extra large
    }
    _bytes.addAll(latin1.encode(text));
    _bytes.add(0x0A); // Line feed
  }

  void leftRight(
    String left,
    String right, {
    bool bold = false,
    int totalWidth = 32,
  }) {
    setAlign(0);
    setBold(bold);
    setTextSize(0, 0);
    final int spaces = totalWidth - left.length - right.length;
    final String line = left + (spaces > 0 ? ' ' * spaces : ' ') + right;
    _bytes.addAll(latin1.encode(line));
    _bytes.add(0x0A);
  }

  void newLine([int count = 1]) {
    for (int i = 0; i < count; i++) {
      _bytes.add(0x0A);
    }
  }

  void paperCut() {
    newLine(3);
    _bytes.addAll([0x1D, 0x56, 0x41, 0x00]); // GS V 65 0 (Feed and Cut)
  }
}

class PrinterService {
  static const String keyConnectionType = 'printer_connection_type';
  static const String keyWifiIp = 'printer_wifi_ip';
  static const String keyWifiPort = 'printer_wifi_port';
  static const String keyBtAddress = 'printer_bt_address';
  static const String keyBtName = 'printer_bt_name';

  final BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;

  // ---------------------------------------------------------------------------
  // CONFIGURATION & PREFERENCES
  // ---------------------------------------------------------------------------

  Future<PrinterConnectionType> getConnectionType() async {
    final prefs = await SharedPreferences.getInstance();
    final type = prefs.getString(keyConnectionType) ?? 'bluetooth';
    return type == 'wifi' ? PrinterConnectionType.wifi : PrinterConnectionType.bluetooth;
  }

  Future<void> saveConnectionType(PrinterConnectionType type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      keyConnectionType,
      type == PrinterConnectionType.wifi ? 'wifi' : 'bluetooth',
    );
  }

  Future<Map<String, dynamic>> getWifiSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'ip': prefs.getString(keyWifiIp) ?? '',
      'port': prefs.getInt(keyWifiPort) ?? 9100,
    };
  }

  Future<void> saveWifiSettings(String ip, int port) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyWifiIp, ip.trim());
    await prefs.setInt(keyWifiPort, port);
  }

  Future<Map<String, String?>> getSavedBtDevice() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'address': prefs.getString(keyBtAddress),
      'name': prefs.getString(keyBtName),
    };
  }

  Future<void> saveBtDevice(String name, String address) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyBtName, name);
    await prefs.setString(keyBtAddress, address);
  }

  // ---------------------------------------------------------------------------
  // CONNECTION STATUS & DIAGNOSTICS
  // ---------------------------------------------------------------------------

  Future<bool> get isConnected async {
    final type = await getConnectionType();
    if (type == PrinterConnectionType.wifi) {
      final wifi = await getWifiSettings();
      final String ip = wifi['ip']?.toString().trim() ?? '';
      return ip.isNotEmpty;
    } else {
      final btConnected = (await bluetooth.isConnected) ?? false;
      if (btConnected) return true;

      // Attempt auto-reconnect if we have a saved Bluetooth device
      final savedBt = await getSavedBtDevice();
      if (savedBt['address'] != null && savedBt['address']!.isNotEmpty) {
        try {
          final devices = await getBondedDevices();
          final match = devices.firstWhere(
            (d) => d.address == savedBt['address'],
            orElse: () => BluetoothDevice(null, null),
          );
          if (match.address != null) {
            return await connect(match);
          }
        } catch (_) {}
      }
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // BLUETOOTH MANAGEMENT
  // ---------------------------------------------------------------------------

  Future<List<BluetoothDevice>> getBondedDevices() async {
    try {
      return await bluetooth.getBondedDevices();
    } on PlatformException {
      return [];
    }
  }

  Future<bool> connect(BluetoothDevice device) async {
    try {
      if ((await bluetooth.isConnected) ?? false) {
        await bluetooth.disconnect();
      }
      await bluetooth.connect(device);
      if (device.name != null && device.address != null) {
        await saveBtDevice(device.name!, device.address!);
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> disconnectBluetooth() async {
    try {
      await bluetooth.disconnect();
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // WI-FI / LAN SOCKET MANAGEMENT
  // ---------------------------------------------------------------------------

  /// Test connection to a thermal printer IP socket (default port 9100)
  Future<bool> testWifiConnection(String ip, int port) async {
    try {
      final socket = await Socket.connect(
        ip.trim(),
        port,
        timeout: const Duration(seconds: 3),
      );
      socket.destroy();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _sendWifiBytes(List<int> bytes) async {
    final wifi = await getWifiSettings();
    final String ip = wifi['ip']?.toString().trim() ?? '';
    final int port = (wifi['port'] as num?)?.toInt() ?? 9100;

    if (ip.isEmpty) {
      throw Exception("No Wi-Fi printer IP configured. Please configure in Printer Settings.");
    }

    final socket = await Socket.connect(
      ip,
      port,
      timeout: const Duration(seconds: 5),
    );
    socket.add(bytes);
    await socket.flush();
    await socket.close();
  }

  // ---------------------------------------------------------------------------
  // RECEIPT PRINTING (BLUETOOTH & WI-FI)
  // ---------------------------------------------------------------------------

  Future<void> printReceipt({
    required String shopName,
    required List<Map<String, dynamic>> items,
    required double total,
    required String date,
  }) async {
    final type = await getConnectionType();

    if (type == PrinterConnectionType.wifi) {
      final builder = EscPosBuilder();
      builder.reset();
      builder.newLine();

      // 1. Header (Large & Centered)
      builder.text(shopName.toUpperCase(), bold: true, align: 1, size: 2);
      builder.text("OFFICIAL RECEIPT", bold: true, align: 1, size: 0);
      builder.text(date, align: 1, size: 0);
      builder.newLine();

      // 2. Stylish Divider
      builder.text("================================", align: 1);

      // 3. Table Header
      builder.leftRight("QTY  ITEM", "PRICE", bold: true);
      builder.text("--------------------------------", align: 1);

      // 4. Dynamic Items List
      for (var item in items) {
        final String name = item['name']?.toString() ?? 'Item';
        final dynamic rawQty = item['qty'] ?? 1;
        final String qtyStr = (rawQty is num && rawQty % 1 != 0)
            ? rawQty.toStringAsFixed(1)
            : (rawQty is num ? rawQty.toInt().toString() : rawQty.toString());
        final double price = (item['price'] is num)
            ? (item['price'] as num).toDouble()
            : 0.0;

        final String displayName =
            name.length > 18 ? "${name.substring(0, 16)}.." : name;
        builder.leftRight(
          "${qtyStr}x  $displayName",
          "KES ${price.toStringAsFixed(0)}",
        );
      }

      // 5. Summary Section
      builder.text("--------------------------------", align: 1);
      builder.newLine();
      builder.leftRight(
        "TOTAL AMOUNT",
        "KES ${total.toStringAsFixed(2)}",
        bold: true,
      );
      builder.newLine();
      builder.text("================================", align: 1);

      // 6. Footer
      builder.text("Goods once sold are not returnable", align: 1);
      builder.text("Thank you for your business!", bold: true, align: 1);
      builder.newLine();
      builder.text("Software by M-Bizna", align: 1);

      // 7. Paper Cut
      builder.paperCut();

      await _sendWifiBytes(builder.bytes);
    } else {
      // Bluetooth ESC/POS
      if (!(await isConnected)) return;

      bluetooth.printNewLine();
      bluetooth.printCustom(shopName.toUpperCase(), 3, 1);
      bluetooth.printCustom("OFFICIAL RECEIPT", 1, 1);
      bluetooth.printCustom(date, 0, 1);
      bluetooth.printNewLine();

      bluetooth.printCustom("================================", 1, 1);
      bluetooth.printLeftRight("QTY  ITEM", "PRICE", 1);
      bluetooth.printCustom("--------------------------------", 1, 1);

      for (var item in items) {
        final String name = item['name']?.toString() ?? 'Item';
        final dynamic rawQty = item['qty'] ?? 1;
        final String qtyStr = (rawQty is num && rawQty % 1 != 0)
            ? rawQty.toStringAsFixed(1)
            : (rawQty is num ? rawQty.toInt().toString() : rawQty.toString());
        final double price = (item['price'] is num)
            ? (item['price'] as num).toDouble()
            : 0.0;

        final String displayName =
            name.length > 18 ? "${name.substring(0, 16)}.." : name;
        bluetooth.printLeftRight(
          "${qtyStr}x  $displayName",
          "KES ${price.toStringAsFixed(0)}",
          0,
        );
      }

      bluetooth.printCustom("--------------------------------", 1, 1);
      bluetooth.printNewLine();
      bluetooth.printLeftRight(
        "TOTAL AMOUNT",
        "KES ${total.toStringAsFixed(2)}",
        2,
      );
      bluetooth.printNewLine();
      bluetooth.printCustom("================================", 1, 1);

      bluetooth.printCustom("Goods once sold are not returnable", 0, 1);
      bluetooth.printCustom("Thank you for your business!", 1, 1);
      bluetooth.printNewLine();
      bluetooth.printCustom("Software by M-Bizna", 0, 1);

      bluetooth.printNewLine();
      bluetooth.printNewLine();
      bluetooth.printNewLine();
      bluetooth.paperCut();
    }
  }

  // ---------------------------------------------------------------------------
  // DAILY CLOSING Z-REPORT (BLUETOOTH & WI-FI)
  // ---------------------------------------------------------------------------

  Future<void> printZReport({
    required String shopName,
    required dynamic closing, // DailyClosing model
  }) async {
    final type = await getConnectionType();

    if (type == PrinterConnectionType.wifi) {
      final builder = EscPosBuilder();
      builder.reset();
      builder.newLine();

      builder.text(shopName.toUpperCase(), bold: true, align: 1, size: 2);
      builder.text("DAILY CLOSING (Z-REPORT)", bold: true, align: 1, size: 1);
      builder.text("Date: ${closing.date}", align: 1);
      builder.newLine();

      builder.text("================================", align: 1);
      builder.text("SALES BREAKDOWN", bold: true, align: 1);
      builder.text("--------------------------------", align: 1);
      builder.leftRight("Cash Sales", "KES ${closing.cashSales.toStringAsFixed(0)}");
      builder.leftRight("M-Pesa Sales", "KES ${closing.mpesaSales.toStringAsFixed(0)}");
      builder.leftRight("Credit Sales", "KES ${closing.creditSales.toStringAsFixed(0)}");
      builder.text("--------------------------------", align: 1);
      builder.leftRight("GROSS SALES", "KES ${closing.grossSales.toStringAsFixed(0)}", bold: true);
      builder.leftRight("TOTAL PROFIT", "KES ${closing.totalProfit.toStringAsFixed(0)}", bold: true);
      builder.leftRight("TOTAL EXPENSES", "-KES ${closing.totalExpenses.toStringAsFixed(0)}");
      builder.leftRight("NET PROFIT", "KES ${closing.netProfit.toStringAsFixed(0)}", bold: true);

      builder.newLine();
      builder.text("================================", align: 1);
      builder.text("CASH RECONCILIATION", bold: true, align: 1);
      builder.text("--------------------------------", align: 1);
      builder.leftRight("Starting Float", "KES ${closing.startingFloat.toStringAsFixed(0)}");
      builder.leftRight("Expected Cash", "KES ${closing.expectedCash.toStringAsFixed(0)}");
      builder.leftRight("Actual Cash Counted", "KES ${closing.actualCash.toStringAsFixed(0)}", bold: true);

      final diff = closing.cashDifference;
      final diffLabel = diff == 0
          ? "BALANCED"
          : (diff > 0 ? "OVERAGE (+)" : "SHORTAGE (-)");
      builder.leftRight("Discrepancy", "$diffLabel KES ${diff.abs().toStringAsFixed(0)}", bold: true);

      builder.text("================================", align: 1);
      builder.text("Closed At: ${closing.closedAt.hour}:${closing.closedAt.minute.toString().padLeft(2, '0')}", align: 1);
      builder.text("System Powered by M-Bizna", align: 1);

      builder.paperCut();

      await _sendWifiBytes(builder.bytes);
    } else {
      if (!(await isConnected)) return;

      bluetooth.printNewLine();
      bluetooth.printCustom(shopName.toUpperCase(), 3, 1);
      bluetooth.printCustom("DAILY CLOSING (Z-REPORT)", 2, 1);
      bluetooth.printCustom("Date: ${closing.date}", 0, 1);
      bluetooth.printNewLine();

      bluetooth.printCustom("================================", 1, 1);
      bluetooth.printCustom("SALES BREAKDOWN", 1, 1);
      bluetooth.printCustom("--------------------------------", 1, 1);
      bluetooth.printLeftRight("Cash Sales", "KES ${closing.cashSales.toStringAsFixed(0)}", 0);
      bluetooth.printLeftRight("M-Pesa Sales", "KES ${closing.mpesaSales.toStringAsFixed(0)}", 0);
      bluetooth.printLeftRight("Credit Sales", "KES ${closing.creditSales.toStringAsFixed(0)}", 0);
      bluetooth.printCustom("--------------------------------", 1, 1);
      bluetooth.printLeftRight("GROSS SALES", "KES ${closing.grossSales.toStringAsFixed(0)}", 1);
      bluetooth.printLeftRight("TOTAL PROFIT", "KES ${closing.totalProfit.toStringAsFixed(0)}", 1);
      bluetooth.printLeftRight("TOTAL EXPENSES", "-KES ${closing.totalExpenses.toStringAsFixed(0)}", 0);
      bluetooth.printLeftRight("NET PROFIT", "KES ${closing.netProfit.toStringAsFixed(0)}", 2);

      bluetooth.printNewLine();
      bluetooth.printCustom("================================", 1, 1);
      bluetooth.printCustom("CASH RECONCILIATION", 1, 1);
      bluetooth.printCustom("--------------------------------", 1, 1);
      bluetooth.printLeftRight("Starting Float", "KES ${closing.startingFloat.toStringAsFixed(0)}", 0);
      bluetooth.printLeftRight("Expected Cash", "KES ${closing.expectedCash.toStringAsFixed(0)}", 0);
      bluetooth.printLeftRight("Actual Cash Counted", "KES ${closing.actualCash.toStringAsFixed(0)}", 1);

      final diff = closing.cashDifference;
      final diffLabel = diff == 0
          ? "BALANCED"
          : (diff > 0 ? "OVERAGE (+)" : "SHORTAGE (-)");
      bluetooth.printLeftRight("Discrepancy", "$diffLabel KES ${diff.abs().toStringAsFixed(0)}", 2);

      bluetooth.printCustom("================================", 1, 1);
      bluetooth.printCustom(
        "Closed At: ${closing.closedAt.hour}:${closing.closedAt.minute.toString().padLeft(2, '0')}",
        0,
        1,
      );
      bluetooth.printCustom("System Powered by M-Bizna", 0, 1);
      bluetooth.printNewLine();
      bluetooth.printNewLine();
      bluetooth.printNewLine();
      bluetooth.paperCut();
    }
  }
}