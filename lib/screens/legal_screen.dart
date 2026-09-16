import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LegalSection {
  final String number;
  final String title;
  final String body;
  final List<String>? bulletPoints;
  final String? callout;

  const LegalSection({
    required this.number,
    required this.title,
    required this.body,
    this.bulletPoints,
    this.callout,
  });
}

class LegalScreen extends StatefulWidget {
  final String type; // 'Terms' or 'Privacy'

  const LegalScreen({super.key, required this.type});

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  late bool _isTerms;

  static const Color _primaryOrange = Color(0xFFFF6B00);

  Color get _containerColor => Theme.of(context).brightness == Brightness.light 
      ? const Color(0xFFF5F6F9) 
      : const Color(0xFF1E1E1E);
  Color get _cardColor => Theme.of(context).brightness == Brightness.light 
      ? Colors.white 
      : const Color(0xFF1E1E1E);
  Color get _textColor => Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF1A1A1A);

  @override
  void initState() {
    super.initState();
    _isTerms = widget.type == 'Terms';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.light 
          ? const Color(0xFFF5F6F9) 
          : const Color(0xFF121212),
      appBar: AppBar(
        title: Text(
          _isTerms ? "Terms of Service" : "Privacy Policy",
          style: GoogleFonts.poppins(
            color: _textColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: _textColor),
      ),
      body: Column(
        children: [
          // 🔘 Document Selector Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _containerColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isTerms = true),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _isTerms ? _primaryOrange : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: _isTerms
                              ? [BoxShadow(color: _primaryOrange.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))]
                              : null,
                        ),
                        child: Text(
                          "Terms of Service",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: _isTerms ? Colors.white : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isTerms = false),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !_isTerms ? _primaryOrange : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: !_isTerms
                              ? [BoxShadow(color: _primaryOrange.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))]
                              : null,
                        ),
                        child: Text(
                          "Privacy Policy",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: !_isTerms ? Colors.white : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 📜 Content Scroll Area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderBanner(),
                  const SizedBox(height: 16),
                  ...(_isTerms ? _termsSections : _privacySections)
                      .map((section) => _buildSectionCard(section)),
                  const SizedBox(height: 16),
                  _buildFooterCard(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _primaryOrange.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _primaryOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _isTerms ? Icons.gavel_rounded : Icons.shield_outlined,
                  color: _primaryOrange,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isTerms ? "M-Bizna Terms of Service" : "M-Bizna Privacy Policy",
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: _textColor,
                      ),
                    ),
                    Text(
                      "Effective Date: September 2026 • Version 2.0",
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 14),
                const SizedBox(width: 6),
                Text(
                  _isTerms
                      ? "Pro Subscription Model • Zero Sales Deductions"
                      : "Kenya Data Protection Act (KDPA 2019) Compliant",
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(LegalSection section) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _primaryOrange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  section.number,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: _primaryOrange,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  section.title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: _textColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            section.body,
            style: GoogleFonts.poppins(
              fontSize: 13,
              height: 1.55,
              color: _textColor.withOpacity(0.85),
            ),
          ),
          if (section.bulletPoints != null && section.bulletPoints!.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...section.bulletPoints!.map((point) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6, right: 8),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: _primaryOrange,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      point,
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        height: 1.5,
                        color: _textColor.withOpacity(0.8),
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
          if (section.callout != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _containerColor,
                borderRadius: BorderRadius.circular(10),
                border: Border(left: BorderSide(color: _primaryOrange, width: 3)),
              ),
              child: Text(
                section.callout!,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  height: 1.45,
                  color: _textColor.withOpacity(0.85),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooterCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _containerColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.mail_outline, color: _primaryOrange, size: 20),
              const SizedBox(width: 8),
              Text(
                "Questions or Data Requests?",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: _textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "If you have inquiries regarding these terms, your subscriber rights, or wish to exercise data access/erasure under the Kenya Data Protection Act, please contact our support team:",
            style: GoogleFonts.poppins(fontSize: 12, height: 1.5, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.email, size: 16, color: _primaryOrange),
                const SizedBox(width: 8),
                Text(
                  "info@nexoracreatives.co.ke",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: _primaryOrange,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 📝 TERMS OF SERVICE SECTIONS
  // ===========================================================================
  static const List<LegalSection> _termsSections = [
    LegalSection(
      number: "1",
      title: "Acceptance of Terms",
      body: "By downloading, installing, accessing, or using M-Bizna (\"the App\", \"the Service\", operated by Iconia / M-Bizna), you enter into a legally binding agreement and agree to comply with these Terms of Service. If you do not agree to these terms, do not install or use the App.",
      callout: "These terms apply to all merchants, shop owners, cashiers, attendants, and authorized operators.",
    ),
    LegalSection(
      number: "2",
      title: "Services & Offline-First Design",
      body: "M-Bizna provides an offline-first Point of Sale (POS), inventory management, stock audit logging, customer debt (\"Deni Manager\") ledger, Bluetooth thermal receipt printing, daily closing (Z-reports), and local smart analytics.",
      bulletPoints: [
        "Core POS functions (catalog lookups, cash sales, stock deductions, cart holds, and manual M-Pesa sales) operate locally on your device without requiring active internet connectivity.",
        "Local records are stored inside SQLite on your device. Internet connectivity is only required for optional cloud synchronization, automated STK Push payment requests, and external SMS delivery.",
      ],
    ),
    LegalSection(
      number: "3",
      title: "Subscription Model (M-Bizna Pro) & Zero Commission",
      body: "M-Bizna operates under a subscription model designed for transparent, predictable pricing:",
      bulletPoints: [
        "Zero Sales Deductions: M-Bizna does NOT deduct any percentage or per-transaction commission from your customer sales.",
        "M-Bizna Pro Features: An active Pro subscription unlocks automated M-Pesa STK Push integration, real-time Google Cloud Firestore backups, multi-device restore, Attendant Mode profit masking, and intelligent low-stock alerts.",
        "Billing & Non-Refundability: Subscriptions (monthly or periodic) are paid in advance via M-Pesa. Once activated, subscription fees are non-refundable. You may turn off auto-renewal at any time in Settings.",
      ],
      callout: "Previous pay-as-you-go wallet transaction fees have been retired in favor of the flat Pro subscription.",
    ),
    LegalSection(
      number: "4",
      title: "Payment Processing & M-Pesa Integration",
      body: "The App facilitates both Manual and Automated mobile money tracking:",
      bulletPoints: [
        "Manual M-Pesa: Merchants display their Till, Paybill, or Phone number. The merchant is solely responsible for verifying the receipt of funds via Safaricom confirmation SMS before dispensing goods or releasing orders.",
        "Automated STK Push: Powered through integrated payment gateways (PayHero Kenya / Safaricom Daraja). M-Bizna does not hold your merchant funds. We are not liable for transaction failures, network delays, or outages originating from telecommunications providers or Safaricom.",
      ],
    ),
    LegalSection(
      number: "5",
      title: "Customer Credit (\"Deni\") Management & SMS",
      body: "The App includes a customer ledger to help you record credit sales, track outstanding balances, and send repayment reminders.",
      bulletPoints: [
        "Record-Keeping Only: M-Bizna is an informational record-keeping tool. We do not underwrite credit, assess customer creditworthiness, or act as a debt collection agency.",
        "SMS Reminders: Automated or manual SMS notifications sent to customers are dispatched strictly upon your instruction. You agree not to use SMS features for harassment or in violation of consumer protection standards.",
      ],
    ),
    LegalSection(
      number: "6",
      title: "Account Security & Role-Based Access",
      body: "You are responsible for safeguarding your device, credentials, and business data.",
      bulletPoints: [
        "M-Bizna Lock: You can enable biometric (fingerprint/face) and device PIN verification to prevent unauthorized viewing of sensitive debt reports and business settings.",
        "Attendant Mode: Owners can toggle Attendant Mode to hide profit margins, buy prices, and sensitive revenue statistics from staff. You are responsible for ensuring staff operate under appropriate permissions.",
      ],
    ),
    LegalSection(
      number: "7",
      title: "Merchant Data Ownership & Backup Responsibilities",
      body: "You retain full and exclusive ownership of all inventory counts, sales histories, expense entries, and customer records you enter into the App.",
      bulletPoints: [
        "Because M-Bizna is offline-first, your primary database lives locally on your physical device.",
        "You are responsible for regularly synchronizing data to the cloud (via M-Bizna Pro) or exporting PDF/CSV reports to prevent data loss in the event of device damage, theft, or factory reset.",
      ],
    ),
    LegalSection(
      number: "8",
      title: "Prohibited Uses",
      body: "You agree not to use M-Bizna for:",
      bulletPoints: [
        "Logging or facilitating transactions for illegal, stolen, or counterfeit goods.",
        "Attempting to decompile, reverse-engineer, exploit, or tamper with the application's software code or cloud APIs.",
        "Sending spam, deceptive, or abusive SMS debt reminders to consumers.",
      ],
    ),
    LegalSection(
      number: "9",
      title: "Limitation of Liability & Disclaimers",
      body: "The App is provided on an \"AS IS\" and \"AS AVAILABLE\" basis without warranties of any kind. To the fullest extent permitted by law, M-Bizna, its developers, and affiliates disclaim all liability for lost profits, loss of data, inventory variances, device hardware failure, or third-party telecom disruptions.",
    ),
    LegalSection(
      number: "10",
      title: "Governing Law & Jurisdiction",
      body: "These Terms are governed by and construed in accordance with the Laws of the Republic of Kenya. Any legal claim or dispute arising under these Terms shall be subject to the exclusive jurisdiction of the competent courts of Kenya.",
    ),
  ];

  // ===========================================================================
  // 🔒 PRIVACY POLICY SECTIONS
  // ===========================================================================
  static const List<LegalSection> _privacySections = [
    LegalSection(
      number: "1",
      title: "Commitment to Data Privacy",
      body: "M-Bizna (\"we\", \"our\", or \"the App\") values your privacy and the confidentiality of your business operations. This Privacy Policy outlines how we collect, process, store, and protect your information in full compliance with the Kenya Data Protection Act, 2019 (KDPA) and internationally accepted data protection standards.",
    ),
    LegalSection(
      number: "2",
      title: "Information We Collect",
      body: "We only collect data necessary to provide seamless retail management and POS functionality:",
      bulletPoints: [
        "Merchant Account Data: Shop name, owner phone number, email address (if authenticated via Firebase), unique Shop ID, and subscription tier.",
        "Store Operational Data: Product names, barcodes, purchase prices, selling prices, inventory stock levels, sales records, margins, expenses, supplier profiles, and Z-reports.",
        "Customer Data (Deni Ledger): Names, phone numbers, and debt balances entered voluntarily by the merchant for credit ledger bookkeeping and SMS reminders.",
        "Payment Metadata: M-Pesa transaction reference codes, external invoice IDs, and timestamps processed securely via PayHero / Safaricom Daraja.",
        "Diagnostic & Crash Logs: Non-personally identifiable diagnostic events via Firebase Crashlytics to detect software bugs and ensure reliability.",
      ],
    ),
    LegalSection(
      number: "3",
      title: "How We Use Your Information",
      body: "We process your data strictly for legitimate operational purposes:",
      bulletPoints: [
        "To process Point of Sale transactions and automatically update inventory stock balances.",
        "To provide secure cloud backup and multi-device synchronization through Google Cloud Firestore (for M-Bizna Pro users).",
        "To verify automated M-Pesa STK Push customer payments in real time.",
        "To dispatch SMS receipts and debt reminder notifications requested by the merchant.",
        "To compute offline business analytics and insights via the on-device Smart Assistant (all assistant calculations run 100% locally on your phone).",
      ],
    ),
    LegalSection(
      number: "4",
      title: "Offline-First Storage & Security Architecture",
      body: "Your business data is engineered with a privacy-by-design architecture:",
      bulletPoints: [
        "Local Device Isolation: Your primary operational database (SQLite) is stored securely in your device's private sandbox storage.",
        "Cloud Security: Cloud sync data is encrypted in transit (HTTPS/TLS 1.3) and access-restricted via Google Firebase security rules strictly scoped to your unique shopId.",
        "Biometric & PIN Lock: M-Bizna Lock provides local on-device hardware security to prevent unauthorized staff or third parties from viewing sensitive reports and debtor ledgers.",
      ],
    ),
    LegalSection(
      number: "5",
      title: "Strict No-Sale Policy & Third-Party Sharing",
      body: "We maintain an absolute NO-SALE policy regarding your information:",
      bulletPoints: [
        "We NEVER sell, rent, monetize, or disclose your sales numbers, revenue, customer phone numbers, or inventory data to third-party advertisers or data brokers.",
        "Google Firebase: Used exclusively for cloud database storage, authentication, and crash telemetry.",
        "PayHero Kenya / Safaricom M-Pesa: Used solely to route mobile money checkout and STK push verification.",
        "SMS Gateway Providers: Used strictly for delivering outgoing merchant notifications and receipts.",
      ],
      callout: "All third-party processors adhere to strict confidentiality agreements and applicable data protection legislation.",
    ),
    LegalSection(
      number: "6",
      title: "Lawful Basis for Processing (KDPA 2019)",
      body: "Under Section 30 of the Kenya Data Protection Act, 2019, our legal bases for processing data include: (a) Performance of Contract (providing POS, stock tracking, and cloud backup), (b) Consent (for SMS dispatches and authentication), and (c) Legitimate Interests (fraud prevention and system stability).",
    ),
    LegalSection(
      number: "7",
      title: "Your Rights Under the Kenya Data Protection Act",
      body: "As a data subject and merchant, you possess complete control over your data:",
      bulletPoints: [
        "Right of Access: You can inspect all stored products, sales histories, and customer ledgers at any time.",
        "Right to Rectification: You can update, edit, or correct any incorrect product, customer, or business record directly in the app.",
        "Right to Erasure (\"Right to be Forgotten\"): You can permanently delete individual customer ledgers, sales records, or perform a complete wipe using the \"Reset App\" feature in Settings.",
        "Right to Data Portability: You can export your complete inventory, sales logs, and debtor statements in standard CSV and PDF formats.",
      ],
    ),
    LegalSection(
      number: "8",
      title: "Data Retention & Account Termination",
      body: "Local records remain on your device until you delete them or clear the app storage. Cloud backup records for active shops are retained until you request account deletion or trigger an app reset, after which cloud records are permanently purged.",
    ),
    LegalSection(
      number: "9",
      title: "Updates to this Policy",
      body: "We may update this Privacy Policy periodically to reflect new features or legal requirements. Material updates will be highlighted in the app's version release notes. Continued use of M-Bizna after updates indicates your acceptance.",
    ),
  ];
}