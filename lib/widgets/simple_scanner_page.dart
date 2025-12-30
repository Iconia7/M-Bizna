import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_fonts/google_fonts.dart';

class SimpleScannerPage extends StatefulWidget {
  @override
  _SimpleScannerPageState createState() => _SimpleScannerPageState();
}

class _SimpleScannerPageState extends State<SimpleScannerPage> {
  // Controller to handle torch and camera switching
  final MobileScannerController controller = MobileScannerController(facing: CameraFacing.back);
  bool _isTorchOn = false;

  @override
  Widget build(BuildContext context) {
    // Theme Colors
    const Color primaryOrange = Color.fromARGB(255, 2, 1, 0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. The Camera Feed
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final String? code = barcodes.first.rawValue;
                if (code != null) {
                  // Vibrate or play sound here if you want
                  Navigator.pop(context, code);
                }
              }
            },
          ),

          // 2. The Dark Overlay with "Cutout"
          // We use a ColorFilter to create a "hole" effect, or simple containers for borders
          _buildOverlay(context),

          // 3. Top Bar (Back Button & Title)
          Positioned(
            top: 50,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.arrow_back, color: Colors.white),
                  ),
                ),
                Text(
                  "Scan Barcode",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 40), // Balancer
              ],
            ),
          ),

          // 4. Bottom Controls (Torch & Hints)
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  "Align code within the frame",
                  style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
                ),
                SizedBox(height: 30),
                GestureDetector(
                  onTap: () {
                    controller.toggleTorch();
                    setState(() {
                      _isTorchOn = !_isTorchOn;
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: _isTorchOn ? primaryOrange : Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isTorchOn ? Icons.flash_on : Icons.flash_off, 
                      color: Colors.white, 
                      size: 28
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Custom Widget to draw the Scan Box
  Widget _buildOverlay(BuildContext context) {
    double scanAreaSize = 280;
    
    return Stack(
      children: [
        // Semi-transparent background
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.6), 
            BlendMode.srcOut
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  backgroundBlendMode: BlendMode.dstOut,
                ),
              ),
              Center(
                child: Container(
                  height: scanAreaSize,
                  width: scanAreaSize,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Orange Border Lines (The Reticle)
        Center(
          child: Container(
            height: scanAreaSize,
            width: scanAreaSize,
            decoration: BoxDecoration(
              border: Border.all(color: Color(0xFFFF6B00), width: 3), // Your Brand Orange
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(
              children: [
                // Corner Accents (Optional visual flair)
                Align(alignment: Alignment.topLeft, child: _cornerWidget()),
                Align(alignment: Alignment.topRight, child: RotatedBox(quarterTurns: 1, child: _cornerWidget())),
                Align(alignment: Alignment.bottomLeft, child: RotatedBox(quarterTurns: 3, child: _cornerWidget())),
                Align(alignment: Alignment.bottomRight, child: RotatedBox(quarterTurns: 2, child: _cornerWidget())),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _cornerWidget() {
    return Container(
      width: 20, height: 20,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white, width: 4),
          left: BorderSide(color: Colors.white, width: 4),
        ),
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}