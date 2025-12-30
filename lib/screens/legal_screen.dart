import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LegalScreen extends StatelessWidget {
  final String type; // 'Terms' or 'Privacy'

  LegalScreen({required this.type});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(type == 'Terms' ? "Terms of Service" : "Privacy Policy", style: GoogleFonts.poppins(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Text(
          type == 'Terms' ? _termsText : _privacyText,
          style: GoogleFonts.poppins(fontSize: 14, height: 1.5),
        ),
      ),
    );
  }

  // 📝 TERMS OF SERVICE TEXT
  final String _termsText = """
**Last Updated: December 2025**

**1. Acceptance of Terms**
By downloading and using M-Bizna ("the App"), you agree to be bound by these terms. If you do not agree, please do not use the App.

**2. Services Provided**
M-Bizna provides Point of Sale (POS) tracking, inventory management, and debt tracking tools. The App integrates with third-party payment providers (PayHero/M-Pesa).

**3. Wallet & Payments**
The App operates on a "Pay-As-You-Go" model.
- Credits purchased for the In-App Wallet are **non-refundable**.
- We are not responsible for transaction failures caused by M-Pesa or PayHero downtime.
- You agree that a transaction fee is deducted from your wallet for specific premium actions (e.g., M-Pesa verification).

**4. User Data**
You are responsible for the accuracy of the data (sales, debts) entered into the App. We are not liable for any financial loss resulting from data errors or app malfunctions.

**5. Limitation of Liability**
The App is provided "as is". The Developer makes no warranties regarding the reliability or accuracy of the software. In no event shall the Developer be liable for lost profits or data.
""";

  // 🔒 PRIVACY POLICY TEXT
  final String _privacyText = """
**Last Updated: December 2025**

**1. Data Collection**
We collect the following data to provide our services:
- **Business Data:** Sales records, inventory lists, and debt records.
- **Customer Data:** Phone numbers and names entered into the "Deni Manager" for the purpose of debt tracking.
- **Payment Data:** M-Pesa transaction codes and amounts (processed securely via PayHero).

**2. How We Use Data**
- To synchronize your inventory across devices (via Firebase).
- To verify M-Pesa payments automatically.
- To generate business performance reports.

**3. Data Sharing**
We do not sell your data. We share data only with:
- **Google Firebase:** For cloud storage and authentication.
- **PayHero/Safaricom:** To process payment requests.

**4. Data Security**
Your data is stored locally on your device and synchronized securely to the cloud. Sensitive actions (like Analytics) are protected by Biometric authentication if enabled.

**5. Your Rights**
You may request the deletion of your account and cloud data by contacting support or using the "Reset App" feature in Settings.
""";
}