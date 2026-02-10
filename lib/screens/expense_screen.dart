import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/expense_provider.dart';
import '../models/expense.dart';
import '../widgets/feedback_dialog.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  // 🎨 THEME COLORS (Dynamic Getters)
  Color get _primaryOrange => const Color(0xFFFF6B00);
  Color get _surfaceColor => Theme.of(context).colorScheme.surface;
  Color get _containerColor => Theme.of(context).brightness == Brightness.light ? const Color(0xFFF5F6F9) : const Color(0xFF121212);
  Color get _cardColor => Theme.of(context).brightness == Brightness.light ? Colors.white : const Color(0xFF1E1E1E);
  Color get _textColor => Theme.of(context).textTheme.bodyLarge?.color ?? const Color(0xFF1A1A1A);

  @override
  void initState() {
    super.initState();
    Future.microtask(() =>
        Provider.of<ExpenseProvider>(context, listen: false).loadExpenses());
  }

  void _showAddExpenseDialog() {
    final descController = TextEditingController();
    final amountController = TextEditingController();
    String selectedCategory = 'Other';
    final categories = ['Rent', 'Utilities', 'Wages', 'Transport', 'Marketing', 'Supplies', 'Other'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text("Add Expense", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: _textColor)),
          backgroundColor: _surfaceColor,
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: descController,
                  style: GoogleFonts.poppins(color: _textColor),
                  decoration: InputDecoration(
                    labelText: "Description", 
                    labelStyle: GoogleFonts.poppins(color: Colors.grey),
                    hintText: "e.g. Electricity Bill",
                    hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.poppins(color: _textColor),
                  decoration: InputDecoration(
                    labelText: "Amount (KES)", 
                    labelStyle: GoogleFonts.poppins(color: Colors.grey),
                    hintText: "0.00",
                    hintStyle: GoogleFonts.poppins(color: Colors.grey.shade400),
                  ),
                ),
                const SizedBox(height: 15),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  dropdownColor: _cardColor,
                  style: GoogleFonts.poppins(color: _textColor),
                  decoration: InputDecoration(
                    labelText: "Category",
                    labelStyle: GoogleFonts.poppins(color: Colors.grey),
                  ),
                  items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: GoogleFonts.poppins(color: _textColor)))).toList(),
                  onChanged: (val) => setDialogState(() => selectedCategory = val!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _primaryOrange),
              onPressed: () {
                final amount = double.tryParse(amountController.text) ?? 0;
                if (descController.text.isNotEmpty && amount > 0) {
                  Provider.of<ExpenseProvider>(context, listen: false).addExpense(
                    Expense(
                      description: descController.text,
                      amount: amount,
                      category: selectedCategory,
                      dateTime: DateTime.now(),
                    ),
                  );
                  Navigator.pop(ctx);
                  FeedbackDialog.show(context, title: "Success", message: "Expense recorded", isSuccess: true);
                }
              },
              child: const Text("Save", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _containerColor,
      appBar: AppBar(
        title: Text("Expense Tracker", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: _textColor)),
        backgroundColor: _containerColor,
        elevation: 0,
        iconTheme: IconThemeData(color: _textColor),
      ),
      body: Consumer<ExpenseProvider>(
        builder: (context, provider, _) {
          if (provider.expenses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey.shade300),
                   const SizedBox(height: 16),
                   Text("No expenses recorded yet", style: GoogleFonts.poppins(color: Colors.grey)),
                ],
              ),
            );
          }

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(25),
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.light ? const Color(0xFF1A1A1A) : const Color(0xFF333333),
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Total Monthly Expenses", style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14)),
                    const SizedBox(height: 8),
                    Text("KES ${provider.totalExpenses.toStringAsFixed(2)}", 
                         style: GoogleFonts.poppins(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  itemCount: provider.expenses.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 15),
                  itemBuilder: (context, index) {
                    final expense = provider.expenses[index];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _cardColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: _containerColor, shape: BoxShape.circle),
                            child: Icon(_getCategoryIcon(expense.category), color: _primaryOrange),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(expense.description, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15, color: _textColor)),
                                Text(DateFormat('MMM dd, yyyy').format(expense.dateTime), style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          ),
                          Text("-KES ${expense.amount.toStringAsFixed(0)}", 
                               style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                            onPressed: () => provider.deleteExpense(expense.id!),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddExpenseDialog,
        backgroundColor: _primaryOrange,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Rent': return Icons.home_work_outlined;
      case 'Utilities': return Icons.lightbulb_outline;
      case 'Wages': return Icons.people_outline;
      case 'Transport': return Icons.directions_bus_outlined;
      case 'Supplies': return Icons.inventory_2_outlined;
      default: return Icons.category_outlined;
    }
  }
}
