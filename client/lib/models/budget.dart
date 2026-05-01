// Mirrors of the budget DTOs on the server. Currency amounts are kept as
// `double` on the client — server returns `BigDecimal` as JSON numbers, and
// the UI rounds to whole kr at render time.

class BudgetCategory {
  final String id;
  final String name;
  final int sortOrder;

  BudgetCategory({required this.id, required this.name, required this.sortOrder});

  factory BudgetCategory.fromJson(Map<String, dynamic> json) => BudgetCategory(
        id: json['id'] as String,
        name: json['name'] as String,
        sortOrder: (json['sortOrder'] as num).toInt(),
      );
}

class CategoryStatus {
  final String categoryId;
  final String categoryName;
  final double budgeted;
  final double spent;
  final double remaining;

  /// Fraction in [0, +∞) where 1.0 = fully spent. Cap to 1.0 for the bar.
  final double utilization;

  CategoryStatus({
    required this.categoryId,
    required this.categoryName,
    required this.budgeted,
    required this.spent,
    required this.remaining,
    required this.utilization,
  });

  factory CategoryStatus.fromJson(Map<String, dynamic> json) => CategoryStatus(
        categoryId: json['categoryId'] as String,
        categoryName: json['categoryName'] as String,
        budgeted: (json['budgeted'] as num).toDouble(),
        spent: (json['spent'] as num).toDouble(),
        remaining: (json['remaining'] as num).toDouble(),
        utilization: (json['utilization'] as num).toDouble(),
      );
}

class MonthlyOverview {
  final String yearMonth; // "2026-05"
  final double totalBudgeted;
  final double totalSpent;
  final double totalRemaining;
  final List<CategoryStatus> categories;

  MonthlyOverview({
    required this.yearMonth,
    required this.totalBudgeted,
    required this.totalSpent,
    required this.totalRemaining,
    required this.categories,
  });

  factory MonthlyOverview.fromJson(Map<String, dynamic> json) => MonthlyOverview(
        yearMonth: json['yearMonth'] as String,
        totalBudgeted: (json['totalBudgeted'] as num).toDouble(),
        totalSpent: (json['totalSpent'] as num).toDouble(),
        totalRemaining: (json['totalRemaining'] as num).toDouble(),
        categories: (json['categories'] as List<dynamic>)
            .map((e) => CategoryStatus.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

enum TransactionSource { tink, manual }

TransactionSource _sourceFromString(String s) =>
    s == 'MANUAL' ? TransactionSource.manual : TransactionSource.tink;

class BudgetTransaction {
  final String id;
  final String? categoryId;
  final String? categoryName;
  final double amount;
  final String description;
  final DateTime bookedDate;
  final TransactionSource source;
  final String? createdByUserId;
  final String? createdByName;
  final DateTime createdAt;

  BudgetTransaction({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.amount,
    required this.description,
    required this.bookedDate,
    required this.source,
    required this.createdByUserId,
    required this.createdByName,
    required this.createdAt,
  });

  factory BudgetTransaction.fromJson(Map<String, dynamic> json) => BudgetTransaction(
        id: json['id'] as String,
        categoryId: json['categoryId'] as String?,
        categoryName: json['categoryName'] as String?,
        amount: (json['amount'] as num).toDouble(),
        description: json['description'] as String,
        bookedDate: DateTime.parse(json['bookedDate'] as String),
        source: _sourceFromString(json['source'] as String),
        createdByUserId: json['createdByUserId'] as String?,
        createdByName: json['createdByName'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
