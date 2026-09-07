class DailyClosing {
  final int? id;
  final String date; // YYYY-MM-DD
  final double startingFloat;
  final double grossSales;
  final double cashSales;
  final double mpesaSales;
  final double creditSales;
  final double totalProfit;
  final double totalExpenses;
  final double netProfit;
  final double expectedCash;
  final double actualCash;
  final double cashDifference; // actualCash - expectedCash (0 = Balanced, <0 = Shortage, >0 = Overage)
  final DateTime closedAt;
  final String? notes;

  DailyClosing({
    this.id,
    required this.date,
    required this.startingFloat,
    required this.grossSales,
    required this.cashSales,
    required this.mpesaSales,
    required this.creditSales,
    required this.totalProfit,
    required this.totalExpenses,
    required this.netProfit,
    required this.expectedCash,
    required this.actualCash,
    required this.cashDifference,
    required this.closedAt,
    this.notes,
  });

  factory DailyClosing.fromMap(Map<String, dynamic> map) {
    return DailyClosing(
      id: map['id'] as int?,
      date: map['date'] as String,
      startingFloat: (map['starting_float'] as num).toDouble(),
      grossSales: (map['gross_sales'] as num).toDouble(),
      cashSales: (map['cash_sales'] as num).toDouble(),
      mpesaSales: (map['mpesa_sales'] as num).toDouble(),
      creditSales: (map['credit_sales'] as num).toDouble(),
      totalProfit: (map['total_profit'] as num).toDouble(),
      totalExpenses: (map['total_expenses'] as num).toDouble(),
      netProfit: (map['net_profit'] as num).toDouble(),
      expectedCash: (map['expected_cash'] as num).toDouble(),
      actualCash: (map['actual_cash'] as num).toDouble(),
      cashDifference: (map['cash_difference'] as num).toDouble(),
      closedAt: DateTime.parse(map['closed_at'] as String),
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'date': date,
      'starting_float': startingFloat,
      'gross_sales': grossSales,
      'cash_sales': cashSales,
      'mpesa_sales': mpesaSales,
      'credit_sales': creditSales,
      'total_profit': totalProfit,
      'total_expenses': totalExpenses,
      'net_profit': netProfit,
      'expected_cash': expectedCash,
      'actual_cash': actualCash,
      'cash_difference': cashDifference,
      'closed_at': closedAt.toIso8601String(),
      'notes': notes,
    };
  }
}
