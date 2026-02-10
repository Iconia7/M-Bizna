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
  
  // 🎨 THEME COLORS (Dynamic Getters)
  Color get _primaryOrange => const Color(0xFFFF6B00);
  Color get _surfaceColor => Theme.of(context).colorScheme.surface;
  Color get _containerColor => Theme.of(context).brightness == Brightness.light ? const Color(0xFFF5F6F9) : const Color(0xFF121212);
  Color get _cardColor => Theme.of(context).brightness == Brightness.light ? Colors.white : const Color(0xFF1E1E1E);
  Color get _textColor => Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF1A1A1A);

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
      backgroundColor: _containerColor,
      appBar: AppBar(
        title: Text("Printer Settings", style: GoogleFonts.poppins(color: _textColor, fontWeight: FontWeight.bold)),
        backgroundColor: _containerColor,
        elevation: 0,
        iconTheme: IconThemeData(color: _textColor),
      ),
      body: Column(
        children: [
          // 1. Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text("Ensure your Thermal Printer is ON and paired in your phone's Bluetooth settings first.", style: TextStyle(color: Colors.grey)),
          ),
          
          if (_isLoading) LinearProgressIndicator(color: _primaryOrange, backgroundColor: _primaryOrange.withOpacity(0.1)),

          // 2. Device List
          Expanded(
            child: ListView.builder(
              itemCount: _devices.length,
              itemBuilder: (ctx, i) {
                final device = _devices[i];
                final isSelected = _selectedDevice?.address == device.address;

                return Card(
                  elevation: 0,
                  color: _cardColor,
                  margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: ListTile(
                    leading: Icon(Icons.print, color: isSelected ? Colors.green : Colors.grey),
                    title: Text(device.name ?? "Unknown Device", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: _textColor)),
                    subtitle: Text(device.address ?? "", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                    trailing: isSelected && _isConnected 
                      ? Text("Connected", style: GoogleFonts.poppins(color: Colors.green, fontWeight: FontWeight.bold))
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).brightness == Brightness.light ? const Color(0xFF1A1A1A) : const Color(0xFF333333),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                          ),
                          onPressed: () => _connect(device),
                          child: const Text("Connect", style: TextStyle(color: Colors.white)),
                        ),
                    onTap: () => _connect(device),
                  ),
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
                  icon: const Icon(Icons.receipt_long, color: Colors.white),
                  label: Text("Print Test Receipt", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: _primaryOrange, padding: const EdgeInsets.all(15)),
                  onPressed: _testPrint,
                ),
              ),
            )
        ],
      ),
    );
  }
}