import 'package:flutter/material.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/printer_service.dart';

class PrinterSettingsScreen extends StatefulWidget {
  @override
  _PrinterSettingsScreenState createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final PrinterService _service = PrinterService();
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _selectedDevice;
  bool _isConnected = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  void _loadDevices() async {
    setState(() => _isLoading = true);
    var devices = await _service.getBondedDevices();
    bool connected = await _service.isConnected;
    setState(() {
      _devices = devices;
      _isConnected = connected;
      _isLoading = false;
    });
  }

  void _connect(BluetoothDevice device) async {
    setState(() => _isLoading = true);
    bool success = await _service.connect(device);
    setState(() {
      _isConnected = success;
      _selectedDevice = success ? device : null;
      _isLoading = false;
    });
    
    if(success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Connected to ${device.name}"), backgroundColor: Colors.green));
    }
  }

  void _testPrint() {
    _service.printReceipt(
      shopName: "Test Shop", 
      date: DateTime.now().toString().substring(0, 16), 
      items: [{'name': 'Test Item', 'qty': 1, 'price': 100.0}], 
      total: 100.0
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Printer Settings", style: GoogleFonts.poppins(color: Colors.black)), backgroundColor: Colors.white, iconTheme: IconThemeData(color: Colors.black)),
      body: Column(
        children: [
          // 1. Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text("Ensure your Thermal Printer is ON and paired in your phone's Bluetooth settings first.", style: TextStyle(color: Colors.grey)),
          ),
          
          if (_isLoading) LinearProgressIndicator(color: Colors.orange),

          // 2. Device List
          Expanded(
            child: ListView.builder(
              itemCount: _devices.length,
              itemBuilder: (ctx, i) {
                final device = _devices[i];
                final isSelected = _selectedDevice?.address == device.address;

                return ListTile(
                  leading: Icon(Icons.print, color: isSelected ? Colors.green : Colors.grey),
                  title: Text(device.name ?? "Unknown Device"),
                  subtitle: Text(device.address ?? ""),
                  trailing: isSelected && _isConnected 
                    ? Text("Connected", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
                    : ElevatedButton(
                        child: Text("Connect"),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                        onPressed: () => _connect(device),
                      ),
                  onTap: () => _connect(device),
                );
              },
            ),
          ),

          // 3. Test Button
          if (_isConnected)
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: Icon(Icons.receipt_long),
                  label: Text("Print Test Receipt"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: EdgeInsets.all(15)),
                  onPressed: _testPrint,
                ),
              ),
            )
        ],
      ),
    );
  }
}