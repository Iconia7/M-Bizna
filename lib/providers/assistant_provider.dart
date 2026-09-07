import 'package:flutter/material.dart';
import '../models/assistant_message.dart';
import '../services/smart_assistant_service.dart';

class AssistantProvider with ChangeNotifier {
  final List<AssistantMessage> _messages = [];
  bool _isLoading = false;

  List<AssistantMessage> get messages => [..._messages];
  bool get isLoading => _isLoading;

  final List<String> quickPrompts = [
    "Today's Sales & Profit",
    "Who owes me money?",
    "Low stock & reorder needs",
    "Highest margin products",
    "Top selling items",
    "This month's expenses",
    "Business health diagnosis",
  ];

  AssistantProvider() {
    _initStarterMessage();
  }

  void _initStarterMessage() {
    _messages.add(AssistantMessage(
      id: "starter_1",
      text: "Hello! I am your M-Bizna Smart Assistant. You can ask me anything about your store's sales, profits, stock, customer debts, or expenses. I work completely offline!",
      isUser: false,
      timestamp: DateTime.now(),
      intent: 'WELCOME',
      actions: [
        AssistantAction(label: "Today's Summary", icon: Icons.point_of_sale, actionType: AssistantActionType.openReports),
        AssistantAction(label: "Debt Book", icon: Icons.people_outline, actionType: AssistantActionType.openScreen, payload: {'screen': 'customers'}),
        AssistantAction(label: "Stock Alerts", icon: Icons.warning_amber_rounded, actionType: AssistantActionType.openSuppliers),
      ],
    ));
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final userMsg = AssistantMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text.trim(),
      isUser: true,
      timestamp: DateTime.now(),
    );

    _messages.add(userMsg);
    _isLoading = true;
    notifyListeners();

    try {
      // Simulate micro-delay for natural chat feel
      await Future.delayed(const Duration(milliseconds: 300));
      final response = await SmartAssistantService.processQuery(text);
      _messages.add(response);
    } catch (e) {
      _messages.add(AssistantMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: "Sorry, I ran into an error reading your store data: $e",
        isUser: false,
        timestamp: DateTime.now(),
      ));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearConversation() {
    _messages.clear();
    _initStarterMessage();
    notifyListeners();
  }
}
