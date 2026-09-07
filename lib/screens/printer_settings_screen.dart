import 'package:flutter/material.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/printer_service.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({Key? key}) : super(key: key);

  @override
  _PrinterSettingsScreenState createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen>
    with SingleTickerProviderStateMixin {
  final PrinterService _service = PrinterService();

  late TabController _tabController;
  PrinterConnectionType _activeType = PrinterConnectionType.bluetooth;

  // Bluetooth State
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _selectedDevice;
  bool _isBtConnected = false;

  // Wi-Fi State
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController = TextEditingController(text: "9100");
  bool _isTestingWifi = false;
  bool? _wifiTestSuccess;

  bool _isLoading = false;

  // 🎨 THEME COLORS (Dynamic Getters)
  Color get _primaryOrange => const Color(0xFFFF6B00);
  Color get _containerColor => Theme.of(context).brightness == Brightness.light
      ? const Color(0xFFF5F6F9)
      : const Color(0xFF121212);
  Color get _cardColor => Theme.of(context).brightness == Brightness.light
      ? Colors.white
      : const Color(0xFF1E1E1E);
  Color get _textColor =>
      Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF1A1A1A);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final newType = _tabController.index == 0
            ? PrinterConnectionType.bluetooth
            : PrinterConnectionType.wifi;
        setState(() => _activeType = newType);
        _service.saveConnectionType(newType);
      }
    });

    _loadSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    // 1. Connection Type
    final savedType = await _service.getConnectionType();
    _activeType = savedType;
    _tabController.index = savedType == PrinterConnectionType.bluetooth ? 0 : 1;

    // 2. Wi-Fi Settings
    final wifi = await _service.getWifiSettings();
    _ipController.text = wifi['ip']?.toString() ?? '';
    _portController.text = (wifi['port'] ?? 9100).toString();

    // 3. Bluetooth Devices & Status
    final devices = await _service.getBondedDevices();
    final connected = (await _service.bluetooth.isConnected) ?? false;
    final savedBt = await _service.getSavedBtDevice();

    BluetoothDevice? matchedDevice;
    if (savedBt['address'] != null) {
      try {
        matchedDevice = devices.firstWhere(
          (d) => d.address == savedBt['address'],
        );
      } catch (_) {}
    }

    setState(() {
      _devices = devices;
      _isBtConnected = connected;
      _selectedDevice = matchedDevice;
      _isLoading = false;
    });
  }

  // ---------------------------------------------------------------------------
  // BLUETOOTH ACTIONS
  // ---------------------------------------------------------------------------

  void _refreshBtDevices() async {
    setState(() => _isLoading = true);
    final devices = await _service.getBondedDevices();
    final connected = (await _service.bluetooth.isConnected) ?? false;
    setState(() {
      _devices = devices;
      _isBtConnected = connected;
      _isLoading = false;
    });
  }

  void _connectBt(BluetoothDevice device) async {
    setState(() => _isLoading = true);
    final success = await _service.connect(device);
    setState(() {
      _isBtConnected = success;
      _selectedDevice = success ? device : _selectedDevice;
      _isLoading = false;
    });

    if (success) {
      await _service.saveConnectionType(PrinterConnectionType.bluetooth);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Connected to ${device.name ?? 'Printer'}"),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to connect. Ensure printer is ON and in range."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // WI-FI ACTIONS
  // ---------------------------------------------------------------------------

  Future<void> _testWifiConnection() async {
    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 9100;

    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a valid printer IP address."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isTestingWifi = true;
      _wifiTestSuccess = null;
    });

    final success = await _service.testWifiConnection(ip, port);

    setState(() {
      _isTestingWifi = false;
      _wifiTestSuccess = success;
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Successfully connected to printer at $ip:$port"),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Could not reach printer at $ip:$port. Check network."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveWifiSettings() async {
    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 9100;

    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a printer IP address before saving."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await _service.saveWifiSettings(ip, port);
    await _service.saveConnectionType(PrinterConnectionType.wifi);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Wi-Fi printer saved ($ip:$port)"),
        backgroundColor: Colors.green,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UNIFIED TEST PRINT
  // ---------------------------------------------------------------------------

  void _testPrint() async {
    try {
      await _service.printReceipt(
        shopName: "Test Duka",
        date: DateTime.now().toString().substring(0, 16),
        items: [
          {'name': 'Test Item 1', 'qty': 1, 'price': 100.0},
          {'name': 'Test Item 2', 'qty': 2.5, 'price': 250.0},
        ],
        total: 350.0,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Test receipt sent to printer!"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Printing failed: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // UI BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _containerColor,
      appBar: AppBar(
        title: Text(
          "Printer Settings",
          style: GoogleFonts.poppins(
            color: _textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: _containerColor,
        elevation: 0,
        iconTheme: IconThemeData(color: _textColor),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _primaryOrange,
          labelColor: _primaryOrange,
          unselectedLabelColor: Colors.grey,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(icon: Icon(Icons.bluetooth), text: "Bluetooth"),
            Tab(icon: Icon(Icons.wifi), text: "Wi-Fi / Network"),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_isLoading)
            LinearProgressIndicator(
              color: _primaryOrange,
              backgroundColor: _primaryOrange.withOpacity(0.1),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBluetoothTab(),
                _buildWifiTab(),
              ],
            ),
          ),
          _buildBottomAction(),
        ],
      ),
    );
  }

  Widget _buildBluetoothTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  "Ensure your Thermal Printer is ON and paired in phone Bluetooth settings.",
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: "Refresh devices",
                onPressed: _refreshBtDevices,
              ),
            ],
          ),
        ),
        Expanded(
          child: _devices.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bluetooth_searching, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          "No paired Bluetooth printers found.\nPair your printer in Android Settings first.",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _devices.length,
                  itemBuilder: (ctx, i) {
                    final device = _devices[i];
                    final isSelected =
                        _selectedDevice?.address == device.address;

                    return Card(
                      elevation: 0,
                      color: _cardColor,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: ListTile(
                        leading: Icon(
                          Icons.print,
                          color: (isSelected && _isBtConnected)
                              ? Colors.green
                              : Colors.grey,
                        ),
                        title: Text(
                          device.name ?? "Unknown Device",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: _textColor,
                          ),
                        ),
                        subtitle: Text(
                          device.address ?? "",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        trailing: (isSelected && _isBtConnected)
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  "Connected",
                                  style: GoogleFonts.poppins(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            : ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      Theme.of(context).brightness ==
                                              Brightness.light
                                          ? const Color(0xFF1A1A1A)
                                          : const Color(0xFF333333),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: () => _connectBt(device),
                                child: const Text(
                                  "Connect",
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                        onTap: () => _connectBt(device),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildWifiTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Info Note
          Card(
            elevation: 0,
            color: _cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: _primaryOrange, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Connect your phone and thermal printer to the same Wi-Fi router or hotspot. Standard ESC/POS printers use port 9100.",
                      style: GoogleFonts.poppins(fontSize: 13, color: _textColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 2. IP & Port Inputs Card
          Card(
            elevation: 0,
            color: _cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Printer Network Details",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: _textColor,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // IP Address
                  TextField(
                    controller: _ipController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: _textColor),
                    decoration: InputDecoration(
                      labelText: "Printer IP Address",
                      hintText: "e.g. 192.168.1.100",
                      prefixIcon: const Icon(Icons.lan_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Port
                  TextField(
                    controller: _portController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: _textColor),
                    decoration: InputDecoration(
                      labelText: "Port Number",
                      hintText: "9100",
                      prefixIcon: const Icon(Icons.numbers_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: _isTestingWifi
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Icon(
                                  _wifiTestSuccess == true
                                      ? Icons.check_circle
                                      : (_wifiTestSuccess == false
                                          ? Icons.error
                                          : Icons.network_check),
                                  color: _wifiTestSuccess == true
                                      ? Colors.green
                                      : (_wifiTestSuccess == false
                                          ? Colors.red
                                          : _primaryOrange),
                                ),
                          label: Text(
                            "Test Ping",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: _textColor,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _isTestingWifi ? null : _testWifiConnection,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.save, color: Colors.white),
                          label: Text(
                            "Save IP",
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryOrange,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _saveWifiSettings,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 3. How to find IP Guide
          Card(
            elevation: 0,
            color: _cardColor.withOpacity(0.6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.help_outline, size: 18, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        "How to find printer IP address",
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _textColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Turn OFF the thermal printer, hold down the FEED button, then turn the POWER on while holding FEED for 3 seconds. The printer will print a self-test slip showing its assigned IP address.",
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.1))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.receipt_long, color: Colors.white),
            label: Text(
              _activeType == PrinterConnectionType.wifi
                  ? "Print Test Receipt (Wi-Fi)"
                  : "Print Test Receipt (Bluetooth)",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryOrange,
              padding: const EdgeInsets.all(15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _testPrint,
          ),
        ),
      ),
    );
  }
}