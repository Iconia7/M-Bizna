import 'package:duka_manager/providers/assistant_provider.dart';
import 'package:duka_manager/providers/customer_provider.dart';
import 'package:duka_manager/providers/shop_provider.dart';
import 'package:duka_manager/screens/close_day_screen.dart';
import 'package:duka_manager/screens/customers_screen.dart';
import 'package:duka_manager/screens/expense_screen.dart';
import 'package:duka_manager/screens/inventory_screen.dart';
import 'package:duka_manager/screens/pos_screen.dart';
import 'package:duka_manager/screens/reports_screen.dart';
import 'package:duka_manager/screens/suppliers_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/assistant_message.dart';
import '../models/customer.dart';

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Color get _primaryOrange => const Color(0xFFFF6B00);
  Color get _surfaceColor => Theme.of(context).colorScheme.surface;
  Color get _containerColor => Theme.of(context).brightness == Brightness.light ? const Color(0xFFF5F6F9) : const Color(0xFF121212);
  Color get _cardColor => Theme.of(context).brightness == Brightness.light ? Colors.white : const Color(0xFF1E1E1E);
  Color get _textColor => Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF1A1A1A);

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSend(String query) {
    if (query.trim().isEmpty) return;
    _inputController.clear();
    Provider.of<AssistantProvider>(context, listen: false).sendMessage(query);
    _scrollToBottom();
  }

  void _handleAction(AssistantAction action) {
    final shop = Provider.of<ShopProvider>(context, listen: false);

    switch (action.actionType) {
      case AssistantActionType.openReports:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen()));
        break;
      case AssistantActionType.openPos:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const POSScreen()));
        break;
      case AssistantActionType.openSuppliers:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const SuppliersScreen()));
        break;
      case AssistantActionType.openScreen:
        final screen = action.payload?['screen'];
        if (screen == 'customers') {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomersScreen()));
        } else if (screen == 'expenses') {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpenseScreen()));
        } else if (screen == 'inventory') {
          Navigator.push(context, MaterialPageRoute(builder: (_) => InventoryScreen()));
        } else if (screen == 'close_day') {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const CloseDayScreen()));
        }
        break;
      case AssistantActionType.whatsappDebtor:
        final phone = action.payload?['phone'] ?? "";
        final name = action.payload?['name'] ?? "";
        final balance = (action.payload?['balance'] as num?)?.toDouble() ?? 0.0;
        final customer = Customer(name: name, phone: phone, currentDebt: balance);
        final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
        customerProvider.sendWhatsAppReminder(customer, shop.shopName);
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final assistant = Provider.of<AssistantProvider>(context);

    return Scaffold(
      backgroundColor: _containerColor,
      appBar: AppBar(
        backgroundColor: _containerColor,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: _primaryOrange.withOpacity(0.15), shape: BoxShape.circle),
              child: Icon(Icons.smart_toy_outlined, color: _primaryOrange, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("M-Bizna Assistant", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: _textColor)),
                Row(
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Text("Offline Intelligence", style: GoogleFonts.poppins(fontSize: 10, color: Colors.green, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: _textColor),
            tooltip: "Clear Conversation",
            onPressed: () => assistant.clearConversation(),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Quick Suggestion Prompt Chips
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: assistant.quickPrompts.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final prompt = assistant.quickPrompts[i];
                return ActionChip(
                  label: Text(prompt, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: _textColor)),
                  backgroundColor: _cardColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: _textColor.withOpacity(0.1))),
                  onPressed: () => _handleSend(prompt),
                );
              },
            ),
          ),

          // 2. Chat Message List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: assistant.messages.length,
              itemBuilder: (ctx, i) {
                final msg = assistant.messages[i];
                return _buildMessageBubble(msg);
              },
            ),
          ),

          // Loading Indicator
          if (assistant.isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: _primaryOrange)),
                  const SizedBox(width: 8),
                  Text("Analyzing store records...", style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),

          // 3. Input Text Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _surfaceColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      style: GoogleFonts.poppins(fontSize: 14, color: _textColor),
                      decoration: InputDecoration(
                        hintText: "Ask about sales, profit, stock, debt...",
                        hintStyle: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
                        prefixIcon: Icon(Icons.search, color: _primaryOrange, size: 20),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                        filled: true,
                        fillColor: _containerColor,
                      ),
                      onSubmitted: _handleSend,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: _primaryOrange,
                    radius: 24,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_upward, color: Colors.white, size: 20),
                      onPressed: () => _handleSend(_inputController.text),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(AssistantMessage msg) {
    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 50),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _primaryOrange,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Text(
            msg.text,
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
      );
    }

    // Assistant Response Card
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16, right: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.smart_toy_outlined, size: 16, color: _primaryOrange),
                const SizedBox(width: 6),
                Text("M-Bizna Assistant", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: _primaryOrange)),
                const Spacer(),
                Text(DateFormat('h:mm a').format(msg.timestamp), style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 8),

            // Message text
            Text(msg.text, style: GoogleFonts.poppins(fontSize: 13, color: _textColor, fontWeight: FontWeight.w500)),

            // Metrics Grid (if present)
            if (msg.metrics != null && msg.metrics!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: msg.metrics!.map((m) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _containerColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: (m.color ?? _primaryOrange).withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (m.icon != null) ...[
                          Icon(m.icon, size: 14, color: m.color ?? _primaryOrange),
                          const SizedBox(width: 6),
                        ],
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.label, style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey)),
                            Text(m.value, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: m.color ?? _textColor)),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],

            // Itemized list (if present)
            if (msg.items != null && msg.items!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Column(
                children: msg.items!.map((item) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _containerColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: _textColor)),
                              Text(item.subtitle, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                        if (item.badgeText != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: (item.badgeColor ?? _primaryOrange).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              item.badgeText!,
                              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: item.badgeColor ?? _primaryOrange),
                            ),
                          ),
                        if (item.extraData != null && item.extraData!['phone'] != null) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.send, color: Color(0xFF25D366), size: 18),
                            tooltip: "Send WhatsApp Statement",
                            onPressed: () {
                              final shop = Provider.of<ShopProvider>(context, listen: false);
                              final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
                              final phone = item.extraData!['phone'] as String? ?? '';
                              final name = item.extraData!['name'] as String? ?? '';
                              final balance = (item.extraData!['balance'] as num?)?.toDouble() ?? 0.0;
                              final customer = Customer(name: name, phone: phone, currentDebt: balance);
                              customerProvider.sendWhatsAppReminder(customer, shop.shopName);
                            },
                          ),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],

            // Action Buttons
            if (msg.actions != null && msg.actions!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: msg.actions!.map((act) {
                  return OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: BorderSide(color: _primaryOrange),
                    ),
                    icon: Icon(act.icon, size: 14, color: _primaryOrange),
                    label: Text(act.label, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: _primaryOrange)),
                    onPressed: () => _handleAction(act),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
